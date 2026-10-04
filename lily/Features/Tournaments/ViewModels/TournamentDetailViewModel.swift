import Foundation
import Observation

/// Owns the tournament shown on the detail screen: fetched by id (a card, a tile, a chat's info button or a room row
/// name only the id), kept on a failed reload, and changed through the entry actions in the `+Entries` file.
@Observable
final class TournamentDetailViewModel {
    enum State: Equatable {
        case loading
        case loaded(TournamentDetail)
        /// Gone, or private and the caller may not see it: "This tournament is no longer available".
        case notFound
        /// Something else went wrong before anything loaded; the popup said what, the screen offers to try again.
        case failed
    }

    let destination: TournamentDestination
    private(set) var state: State = .loading
    private(set) var isBusy = false

    /// Shared with the `+Entries` file, hence not `private`.
    let repository: any TournamentRepository
    let identity: any IdentityProvider
    let reporter: GroupErrorReporter
    let logger: any Logging
    let tryAgainDelay: Duration
    let now: () -> Date
    let pushOptIn: any PushOptIn
    let onChange: @MainActor (Tournament) -> Void
    private let groupRepository: any GroupRepository
    private let navigation: AppNavigation
    private let recorder: any InteractionRecorder
    private var hasRecordedView = false

    init(destination: TournamentDestination,
         repository: any TournamentRepository,
         groupRepository: any GroupRepository,
         identity: any IdentityProvider,
         navigation: AppNavigation,
         reporter: GroupErrorReporter,
         recorder: any InteractionRecorder,
         logger: any Logging,
         tryAgainDelay: Duration = AppConfig.API.tryAgainDelay,
         now: @escaping () -> Date = { .now },
         pushOptIn: any PushOptIn = NoPushOptIn(),
         onChange: @escaping @MainActor (Tournament) -> Void) {
        self.destination = destination
        self.repository = repository
        self.groupRepository = groupRepository
        self.identity = identity
        self.navigation = navigation
        self.reporter = reporter
        self.recorder = recorder
        self.logger = logger
        self.tryAgainDelay = tryAgainDelay
        self.now = now
        self.pushOptIn = pushOptIn
        self.onChange = onChange
    }

    var detail: TournamentDetail? {
        if case .loaded(let detail) = state { return detail }
        return nil
    }
    var tournament: Tournament? { detail?.tournament }
    /// The name shows until the detail answers.
    var name: String { tournament?.name ?? destination.name }
    var role: TournamentRole {
        tournament.map { TournamentRole(tournament: $0, userID: identity.currentUserID) } ?? .guest
    }
    var participation: TournamentParticipation {
        tournament.map { TournamentParticipation(tournament: $0, userID: identity.currentUserID, now: now()) } ?? .hidden
    }
    /// The organiser edits and cancels while the tournament runs; nothing once it is over.
    var canEdit: Bool { role.isOrganizer && !(tournament?.status.isOver ?? true) }
    var canCancel: Bool { canEdit }
    /// The organiser drops entries while registration is open.
    var canRemoveEntries: Bool { role.isOrganizer && tournament?.status == .registration }
    /// Members of the room chat: the organiser and every player in.
    var canOpenChat: Bool { AppConfig.FeatureFlags.chat && (role.isOrganizer || (tournament?.hasEntered ?? false)) }
    var showsMenu: Bool { canOpenChat || canEdit || canCancel }
    /// Entries are members-level information, like a roster: shown to signed-in callers only.
    var showsEntries: Bool { identity.currentUserID != nil }
    /// The organiser's profile, when the caller may open it: signed in, and not the organiser themselves.
    var organizerProfile: UserProfileDestination? {
        guard let tournament, identity.currentUserID != nil, !role.isOrganizer else { return nil }
        return UserProfileDestination(userId: tournament.organizerUserId, displayName: tournament.organizerName)
    }

    func isSelf(_ userID: String) -> Bool {
        userID == identity.currentUserID
    }

    /// Fetches the detail; a loaded detail stays on screen while the view's task re-runs it and when that reload fails,
    /// so coming back from a pushed profile never blanks the screen.
    func load() async {
        if detail == nil { state = .loading }
        do {
            let detail = try await repository.tournament(id: destination.id)
            state = .loaded(detail)
            recordViewed(detail.tournament)
        } catch AppError.tournamentNotFound {
            logger.info(.tournaments, "Tournament \(destination.id) is not available to the caller")
            if detail == nil { state = .notFound }
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.tournaments, "Loading tournament \(destination.id) failed: \(error)")
            if detail == nil { state = .failed }
            reporter.report(error)
        }
    }

    /// Takes the detail as the edit sheet or an action answered it: shown here and handed on to the lists behind.
    func accept(_ detail: TournamentDetail) {
        state = .loaded(detail)
        onChange(detail.tournament)
    }

    /// One view per screen instance, however often the view's task restarts.
    private func recordViewed(_ tournament: Tournament) {
        guard !hasRecordedView else { return }
        hasRecordedView = true
        recorder.record(.tournamentViewed(tournament, at: now()))
    }

    /// The room is a group under the tournament's id; fetched for the chat, which needs the group as the backend holds it.
    func openChat() async {
        await perform("Open chat") { [self] in
            let room = try await groupRepository.group(id: destination.id)
            navigation.open(chat: room)
        }
    }

    /// The organiser calls it off; the room stays, the lists learn of it.
    func cancel() async {
        await perform("Cancel") { [self] in
            let cancelled = try await repository.cancel(id: destination.id)
            accept(cancelled)
            logger.info(.tournaments, "Tournament \(cancelled.id) cancelled")
        }
    }

    /// One action at a time; `TRY_AGAIN` is repeated once; every failure reaches the popup through the reporter, so a
    /// `TERMS_REQUIRED` raises the terms sheet. Shared with the `+Entries` file.
    func perform(_ action: String, _ work: () async throws -> Void) async {
        guard !isBusy, identity.currentUserID != nil else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await LostRace.attemptTwice(delay: tryAgainDelay, onRetry: { logRetry(action) }, work)
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.tournaments, "\(action) failed for tournament \(destination.id): \(error)")
            reporter.report(error)
        }
    }

    private func logRetry(_ action: String) {
        logger.info(.tournaments, "\(action) lost a race for tournament \(destination.id); retrying once")
    }
}
