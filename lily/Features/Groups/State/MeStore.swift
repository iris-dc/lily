import Foundation
import Observation

/// The caller's `GET /api/me`, loaded once per signed-in session: whether the terms are owed, whether they operate,
/// and where live chat connects. A failed load is logged and not shown: a write the terms gate refuses reaches the
/// popup on its own and re-raises the sheet through `noteTermsRequired()`. An acceptance re-reads the account first,
/// so the version it sends is the current one (Laurel answers 400 for a stale one).
@Observable
final class MeStore: SessionObserver {
    private(set) var account: Account?
    /// Set when a write answered `TERMS_REQUIRED` (a race, or a version bump since the load); cleared by acceptance
    /// and by a load that shows the terms accepted.
    private(set) var termsOutdated = false
    private var loadedUserID: String?
    /// Why the last load failed, kept for an acceptance whose reload left no account; cleared by a load that landed.
    private var loadFailure: AppError?
    private let load = SingleFlight()

    private let repository: any MeRepository
    private let identity: any IdentityProvider
    private let errorCenter: ErrorCenter
    private let logger: any Logging

    init(repository: any MeRepository, identity: any IdentityProvider, errorCenter: ErrorCenter, logger: any Logging) {
        self.repository = repository
        self.identity = identity
        self.errorCenter = errorCenter
        self.logger = logger
    }

    /// Whether the current terms are still owed: the backend said so on the load, or a write was refused since.
    var needsTerms: Bool { termsOutdated || account.map { !$0.termsAccepted } ?? false }
    var isOperator: Bool { account?.isOperator ?? false }
    var realtimeEndpoint: URL? { account?.realtimeEndpoint }
    /// Whether the backend takes chat attachments; off until the account is known, so no button shows for nothing.
    var attachmentsEnabled: Bool { account?.attachmentsEnabled ?? false }
    var isLoading: Bool { load.isRunning }

    /// Loads for the signed-in user unless already loaded for them; a guest has nothing to load and is cleared.
    func loadIfNeeded() async {
        guard let userID = identity.currentUserID else {
            clear()
            return
        }
        guard account == nil || loadedUserID != userID else {
            logger.debug(.cache, "Account reused for the signed-in user")
            return
        }
        await reload()
    }

    /// A call made while one is in flight joins it; an answer that arrives after the caller signed out or changed is
    /// dropped.
    func reload() async {
        guard let userID = identity.currentUserID else {
            clear()
            return
        }
        await load.run { [self] in await performLoad(for: userID) }
    }

    private func performLoad(for userID: String) async {
        do {
            let loaded = try await repository.me()
            guard identity.isStillCaller(userID, orDrop: "Account answer", logger: logger) else { return }
            account = loaded
            loadedUserID = userID
            loadFailure = nil
            if loaded.termsAccepted { termsOutdated = false }
            logger.info(.groups, "Account loaded; terms accepted: \(loaded.termsAccepted)")
        } catch {
            guard !AppError.isCancellation(error) else {
                logger.debug(.groups, "Loading the account cancelled")
                return
            }
            guard identity.isStillCaller(userID, orDrop: "Account answer", logger: logger) else { return }
            loadFailure = AppError.wrapping(error)
            logger.warning(.groups, "Loading the account failed: \(error)")
        }
    }

    /// Re-reads the account first, so a version bumped since the sheet opened is accepted rather than refused as
    /// stale. `false` when nothing was recorded; the popup says why, unless the caller signed out or left mid-request.
    func acceptTerms() async -> Bool {
        await reload()
        guard let account else {
            reportUnreadableAccount()
            return false
        }
        do {
            let acceptance = try await repository.acceptTerms(version: account.termsVersion)
            self.account = account.acceptingTerms(acceptance)
            termsOutdated = false
            logger.info(.groups, "Terms v\(acceptance.acceptedTermsVersion) accepted")
            return true
        } catch {
            guard !AppError.isCancellation(error) else { return false }
            logger.error(.groups, "Accepting the terms failed: \(error)")
            errorCenter.report(error)
            return false
        }
    }

    /// No account after a reload is a failed read, which the popup shows, or a sign-out meanwhile, which is quiet.
    private func reportUnreadableAccount() {
        guard let loadFailure else { return }
        logger.error(.groups, "Accepting the terms failed: the account could not be read: \(loadFailure)")
        errorCenter.report(loadFailure)
    }

    func noteTermsRequired() {
        termsOutdated = true
    }

    func sessionDidEnd() {
        logger.debug(.cache, "Account cleared on sign-out")
        clear()
    }

    private func clear() {
        account = nil
        loadedUserID = nil
        loadFailure = nil
        termsOutdated = false
    }
}
