import Foundation
import Observation

/// The invite-people sheet: the people the caller shares a group or a game with, narrowed by name as the caller types,
/// and one invite per row. The invitee answers from their inbox; nothing here waits for that answer.
@Observable
final class InvitePeopleViewModel {
    /// What the sheet shows under its title.
    enum Content: Equatable {
        case loading, failed, nobody, noMatches, people
    }

    let group: SportGroup
    private(set) var candidates: [InviteCandidate] = []
    private(set) var isLoading = false
    private(set) var loadFailed = false
    /// Rows whose invite is on its way; their button shows a spinner and a second tap is dropped.
    private(set) var sendingUserIDs: Set<String> = []
    var query = ""
    private var hasLoaded = false

    private let repository: any InviteRepository
    private let reporter: GroupErrorReporter
    private let logger: any Logging
    private let tryAgainDelay: Duration

    init(group: SportGroup,
         repository: any InviteRepository,
         reporter: GroupErrorReporter,
         logger: any Logging,
         tryAgainDelay: Duration = AppConfig.API.tryAgainDelay) {
        self.group = group
        self.repository = repository
        self.reporter = reporter
        self.logger = logger
        self.tryAgainDelay = tryAgainDelay
    }

    /// The candidates whose name contains the query (case and diacritics aside), every one while the query is blank.
    var visible: [InviteCandidate] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return candidates }
        return candidates.filter { $0.displayName.localizedStandardContains(needle) }
    }

    var content: Content {
        guard hasLoaded else { return loadFailed ? .failed : .loading }
        guard !candidates.isEmpty else { return .nobody }
        return visible.isEmpty ? .noMatches : .people
    }

    /// The search field is worth showing once there is someone to search among.
    var showsSearch: Bool { !candidates.isEmpty }

    func isSending(_ candidate: InviteCandidate) -> Bool {
        sendingUserIDs.contains(candidate.userId)
    }

    /// The candidates as the backend sees them now; a failure keeps what is shown and reaches the popup.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            candidates = try await repository.candidates(groupID: group.id)
            hasLoaded = true
            loadFailed = false
            logger.debug(.groups, "Loaded \(candidates.count) invite candidates for group \(group.id)")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            loadFailed = true
            logger.error(.groups, "Loading invite candidates for group \(group.id) failed: \(error)")
            reporter.report(error)
        }
    }

    /// One invite per row at a time; `TRY_AGAIN` is repeated once; a row already invited sends nothing more.
    func invite(_ candidate: InviteCandidate) async {
        guard let current = candidates.first(where: { $0.userId == candidate.userId }),
              !current.isInvited, !sendingUserIDs.contains(current.userId) else { return }
        sendingUserIDs.insert(current.userId)
        defer { sendingUserIDs.remove(current.userId) }
        do {
            _ = try await LostRace.attemptTwice(delay: tryAgainDelay,
                                                onRetry: { logRetry(current) },
                                                { try await repository.invite(groupID: group.id, userID: current.userId) })
            markInvited(current.userId)
            logger.info(.groups, "Invite sent to \(current.userId) for group \(group.id)")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.groups, "Invite to \(current.userId) for group \(group.id) failed: \(error)")
            reporter.report(error)
        }
    }

    private func markInvited(_ userID: String) {
        guard let index = candidates.firstIndex(where: { $0.userId == userID }) else { return }
        candidates[index] = candidates[index].markingInvited()
    }

    private func logRetry(_ candidate: InviteCandidate) {
        logger.info(.groups, "Invite to \(candidate.userId) for group \(group.id) lost a race; retrying once")
    }
}
