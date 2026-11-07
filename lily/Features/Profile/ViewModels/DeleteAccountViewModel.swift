import Foundation
import Observation

/// The delete-account flow behind `DeleteAccountSheet` (the deletion contract): the advisory counts summary, the
/// destructive confirmation's outcome, the locked wait that polls the account read until the deletion landed, and the
/// one-time acknowledgment whose tap alone ends the session (the relocation contract's teardown order). Anywhere past
/// the confirm, a 401 (`.sessionExpired`) or `USER_NOT_FOUND` is the deletion landing (`DeletionSettle`), never a failure.
@Observable
final class DeleteAccountViewModel {
    /// The advisory preview; `nil` while it loads or when it failed, which blocks nothing — the backend re-derives
    /// everything on execute, so a failed preview must never stand between the caller and erasure.
    private(set) var plan: DeletionPlan?
    private(set) var isLoadingPlan = false
    /// The request or the poll is out: the sheet is locked and Cancel is gone.
    private(set) var isDeleting = false
    /// The deletion landed: the sheet shows the one-time acknowledgment; only its tap ends the session.
    private(set) var isDeleted = false

    private let repository: any MeRepository
    private let session: any AccountDeletionSession
    private let errorCenter: ErrorCenter
    private let logger: any Logging
    private let sleep: Sleep

    init(repository: any MeRepository,
         session: any AccountDeletionSession,
         errorCenter: ErrorCenter,
         logger: any Logging,
         sleep: @escaping Sleep = systemSleep) {
        self.repository = repository
        self.session = session
        self.errorCenter = errorCenter
        self.logger = logger
        self.sleep = sleep
    }

    /// Locked while the deletion runs and on the acknowledgment: past the confirm, the acknowledge tap is the only way out.
    var isLocked: Bool { isDeleting || isDeleted }

    /// One localized plural line per non-zero count, the zero-count lines dropped (the relocation contract's rendering
    /// rule); the always-true messages sentence is the view's and renders whatever this answers.
    var summaryLines: [String] { Self.lines(for: plan) }

    nonisolated static func lines(for plan: DeletionPlan?) -> [String] {
        guard let plan else { return [] }
        typealias Copy = AppBranding.DeleteAccount
        let counts: [(Int, (Int) -> String)] = [(plan.groupsTransferring, Copy.groupsTransferring),
                                                (plan.groupsDeleted, Copy.groupsDeleted),
                                                (plan.eventsCancelled, Copy.eventsCancelled),
                                                (plan.entriesWithdrawn, Copy.entriesWithdrawn),
                                                (plan.tournamentsCancelled, Copy.tournamentsCancelled)]
        return counts.filter { $0.0 > 0 }.map { $0.1($0.0) }
    }

    /// Loads the preview once per presentation; a failure reports the popup and leaves the counts out. Locked or
    /// landed it reports nothing: the account-deleted teardown re-instantiates the sheet's content, whose fresh
    /// `.task` re-runs this against the dead session, and its 401 must never raise the "Session expired" popup over
    /// the signed-out landing (the design's client end path suppresses it).
    func prepare() async {
        guard plan == nil, !isLoadingPlan, !isLocked else { return }
        isLoadingPlan = true
        defer { isLoadingPlan = false }
        do {
            plan = try await repository.deletionPlan()
        } catch {
            guard !AppError.isCancellation(error) else { return }
            if isLocked || landed(error) {
                logger.debug(.auth, "Deletion plan load found the session ended: \(error)")
                return
            }
            logger.warning(.auth, "Deletion plan load failed: \(error)")
            errorCenter.report(error)
        }
    }

    /// The destructive confirmation's outcome: expired-session reports stand down, the backend claims the job
    /// (a replay lands in the same job), and the poll runs until an account read settles it. A refusal before the
    /// claim reports the popup, stands the expired-session end back up and unlocks the sheet; a 401 instead means a
    /// completed job and settles at once.
    func confirmDeletion() async {
        guard !isLocked else { return }
        isDeleting = true
        session.beginAccountDeletion()
        logger.info(.auth, "Account deletion requested")
        do {
            try await repository.deleteAccount()
        } catch {
            if landed(error) { return markDeleted(afterPolls: 0) }
            isDeleting = false
            session.cancelAccountDeletion()
            guard !AppError.isCancellation(error) else { return }
            logger.error(.auth, "Account deletion request failed: \(error)")
            errorCenter.report(error)
            return
        }
        await poll()
    }

    /// The one-time acknowledgment's tap: the only trigger of the account-deleted session end (the pinned teardown
    /// order), which then collapses the whole presentation chain over the signed-out landing.
    func acknowledge() async {
        guard isDeleted else { return }
        await session.endDeletedSession()
    }

    /// The inverted success check: `GET /api/me` is re-read until a 401 or `USER_NOT_FOUND` says the deletion landed;
    /// an answer means the job still runs and any other failure settles on a later read, so the loop never gives up.
    private func poll() async {
        var polls = 0
        while true {
            guard (try? await sleep(AppConfig.AccountDeletion.pollInterval)) != nil else {
                logger.debug(.auth, "Account deletion poll cancelled; a later read settles the outcome")
                return
            }
            polls += 1
            do {
                _ = try await repository.me()
            } catch {
                if landed(error) { return markDeleted(afterPolls: polls) }
                logger.debug(.auth, "Account deletion poll unsettled: \(error)")
            }
        }
    }

    private func markDeleted(afterPolls polls: Int) {
        isDeleting = false
        isDeleted = true
        logger.info(.auth, "Account deletion landed after \(polls) polls")
    }

    nonisolated private func landed(_ error: any Error) -> Bool {
        (error as? AppError).map(DeletionSettle.isLanded) ?? false
    }
}
