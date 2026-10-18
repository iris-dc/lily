import Foundation
import Observation

/// Owns the tournament shown on the detail screen: fetched by id; a card or a tile hands its copy over and the screen
/// draws it until the fetch answers (a chat's info button or a room row know the id and the name alone). A loaded
/// detail is kept on a failed reload, and changed through the entry actions in the `+Entries` file and the start and the
/// results in the `+Matches` file. Who sees the menu, its items, the entries segment and the organiser's profile is
/// `TournamentPermissions`, decided from the tournament on screen (loaded, else the opener's copy) and the caller.
@Observable
final class TournamentDetailViewModel {
    enum State: Equatable {
        case loading
        /// The opener's copy, drawn while the detail loads; its entries and matches are not known yet.
        case previewing(Tournament)
        case loaded(TournamentDetail)
        /// Gone, or private and the caller may not see it: "This tournament is no longer available".
        case notFound
        /// Something else went wrong before anything loaded; the popup said what, the screen offers to try again.
        case failed
    }

    let destination: TournamentDestination
    private(set) var state: State
    /// A load that failed while the opener's copy is on screen: the copy stays, the segment slot offers Try again.
    private(set) var previewLoadFailed = false
    private(set) var isBusy = false
    /// The tournament was there and is gone now (an operator deleted it): the screen dismisses, as a gone group's does.
    private(set) var isGone = false

    /// Shared with the `+Entries` file, hence not `private`.
    let repository: any TournamentRepository
    /// Entering and leaving move the caller's room, so the entry writes reload Mine and a gone tournament drops it.
    let myGroups: MyGroupsStore
    let identity: any IdentityProvider
    let reporter: GroupErrorReporter
    let logger: any Logging
    let now: () -> Date
    let pushOptIn: any PushOptIn
    let onChange: @MainActor (Tournament) -> Void
    private let groupRepository: any GroupRepository
    private let navigation: AppNavigation
    private let recorder: any InteractionRecorder
    private let gate: WriteGate
    /// Tournament changes made anywhere; the screen reloads when it moved past the version it last agreed with.
    private let changes: ChangeTracker
    private var acknowledgedVersion: Int?
    private var hasRecordedView = false
    /// Bumped by every load and every accepted answer, so an older load's answer is dropped, its failure too: a
    /// pull-to-refresh runs outside the keyed task and `perform` does not wait for it, so a Confirm or Join answering
    /// while a slow refresh is out would otherwise be overwritten by the older page.
    private var loadGeneration = 0
    /// The match the destination named, once the first loaded detail holds it; the view presents it and consumes it.
    private(set) var linkedMatchToShow: String?
    private var hasDecidedLinkedMatch = false

    init(destination: TournamentDestination,
         repository: any TournamentRepository,
         groupRepository: any GroupRepository,
         myGroups: MyGroupsStore,
         identity: any IdentityProvider,
         navigation: AppNavigation,
         changes: ChangeTracker,
         reporter: GroupErrorReporter,
         recorder: any InteractionRecorder,
         logger: any Logging,
         tryAgainDelay: Duration = AppConfig.API.tryAgainDelay,
         now: @escaping () -> Date = { .now },
         pushOptIn: any PushOptIn = NoPushOptIn(),
         onChange: @escaping @MainActor (Tournament) -> Void) {
        self.destination = destination
        state = Self.initialState(for: destination)
        self.repository = repository
        self.groupRepository = groupRepository
        self.myGroups = myGroups
        self.identity = identity
        self.navigation = navigation
        self.changes = changes
        self.reporter = reporter
        self.recorder = recorder
        self.logger = logger
        gate = WriteGate(category: .tournaments,
                         logger: logger,
                         tryAgainDelay: tryAgainDelay,
                         report: { reporter.report($0) },
                         isExpected: { $0.isTournamentRefusal })
        self.now = now
        self.pushOptIn = pushOptIn
        self.onChange = onChange
    }

    var detail: TournamentDetail? {
        if case .loaded(let detail) = state { return detail }
        return nil
    }
    /// The opener's copy while the detail is still loading.
    var preview: Tournament? {
        if case .previewing(let tournament) = state { return tournament }
        return nil
    }
    /// The loaded tournament, else the opener's copy, so the header, the facts and the control never wait for the fetch.
    var tournament: Tournament? { detail?.tournament ?? preview }
    /// What the screen draws: the loaded detail, else the opener's copy with nothing under it yet; `nil` while nothing
    /// is known. One value for both, so the screen keeps its scroll view across the switch.
    var shownDetail: TournamentDetail? { detail ?? preview.map { TournamentDetail(tournament: $0) } }
    var isPreviewing: Bool { preview != nil }
    /// The name shows until the detail answers.
    var name: String { tournament?.name ?? destination.name }
    var role: TournamentRole {
        tournament.map { TournamentRole(tournament: $0, userID: identity.currentUserID) } ?? .guest
    }
    var participation: TournamentParticipation {
        tournament.map { TournamentParticipation(tournament: $0, userID: identity.currentUserID, now: now()) } ?? .hidden
    }
    /// Who may do what on this detail, from the tournament on screen (loaded, else the opener's copy) and the caller;
    /// `.none` while neither is known.
    var permissions: TournamentPermissions {
        tournament.map {
            TournamentPermissions(tournament: $0,
                                  userID: identity.currentUserID,
                                  now: now(),
                                  chatEnabled: AppConfig.FeatureFlags.chat)
        } ?? .none
    }
    var reportTarget: ReportTarget { .tournament(id: destination.id) }
    /// The winning entry's name once the tournament is completed; `nil` before and when the entry is unknown.
    var winnerName: String? {
        guard let detail, detail.tournament.status == .completed else { return nil }
        return detail.tournament.winnerEntryId.flatMap(detail.entry(id:))?.name
    }

    func isSelf(_ userID: String) -> Bool {
        userID == identity.currentUserID
    }

    /// The view's one entry, re-run on every change of the tracker: the first load, and a reload whenever a tournament
    /// changed elsewhere (a live room event, a sibling screen) since this screen last agreed with the tracker. A change
    /// this screen made itself is acknowledged in `accept`, so it costs no second request; a gone tournament asks for
    /// nothing more.
    func loadIfNeeded() async {
        let version = changes.version
        guard !isGone, detail == nil || acknowledgedVersion != version else { return }
        acknowledgedVersion = version
        await load()
    }

    /// Fetches the detail. With `reportingFailures` a failure reaches the popup and sets `.failed` only while nothing
    /// was loaded yet, so coming back from a pushed profile never blanks the screen. The refetch after an entry write
    /// passes `false`: the fresh detail goes on to the lists through `accept`, and a failure records a change for the
    /// view's task to reload on, because the write landed and the stale control must not stay. A 404 marks the
    /// tournament gone either way; an answer older than a write accepted meanwhile is dropped, its failure too.
    func load(reportingFailures: Bool = true) async {
        if detail == nil { state = Self.initialState(for: destination) }
        previewLoadFailed = false
        loadGeneration += 1
        let generation = loadGeneration
        do {
            let fresh = try await repository.tournament(id: destination.id)
            guard generation == loadGeneration else { return }
            if reportingFailures { state = .loaded(fresh) } else { accept(fresh) }
            decideLinkedMatch(in: fresh)
            recordViewed(fresh.tournament)
        } catch AppError.tournamentNotFound {
            guard generation == loadGeneration else { return }
            logger.info(.tournaments, "Tournament \(destination.id) is not available to the caller")
            markGone()
        } catch {
            guard !AppError.isCancellation(error), generation == loadGeneration else { return }
            if reportingFailures { reportLoadFailure(error) } else { noteRefreshFailure(error) }
        }
    }

    /// The opener's copy stays on screen with a Try again under it; the failed state is for a screen with nothing to show.
    private func reportLoadFailure(_ error: any Error) {
        logger.error(.tournaments, "Loading tournament \(destination.id) failed: \(error)")
        if preview != nil {
            previewLoadFailed = true
        } else if detail == nil {
            state = .failed
        }
        reporter.report(error)
    }

    /// The opener's copy when it handed one over, else the spinner.
    private static func initialState(for destination: TournamentDestination) -> State {
        destination.preview.map(State.previewing) ?? .loading
    }

    /// The popup stays with the write that did land. The change is recorded without being acknowledged, so the view's
    /// keyed task runs `loadIfNeeded` again and asks, and the lists behind reload too.
    private func noteRefreshFailure(_ error: any Error) {
        logger.warning(.tournaments, "Could not refresh tournament \(destination.id) after a write: \(error)")
        changes.recordChange()
    }

    /// Takes the detail as the edit sheet or an action answered it: shown here and handed on to the lists behind, whose
    /// change the tracker records; that version is this screen's own and needs no reload.
    func accept(_ detail: TournamentDetail) {
        loadGeneration += 1
        state = .loaded(detail)
        onChange(detail.tournament)
        acknowledgedVersion = changes.version
    }

    /// A 404 shows the empty state when nothing was loaded yet (a stale row named the tournament). After a loaded detail
    /// it means the tournament was deleted meanwhile: the screen dismisses, its room leaves Mine and the lists behind
    /// are told to reload; that version is this screen's own.
    private func markGone() {
        loadGeneration += 1
        let wasLoaded = detail != nil
        state = .notFound
        guard wasLoaded else { return }
        isGone = true
        myGroups.remove(id: destination.id)
        changes.recordChange()
        acknowledgedVersion = changes.version
    }

    /// The first successful load decides, whether it came from the keyed task, Try again or a pull; a reload or an own
    /// `accept` never raises the match again.
    private func decideLinkedMatch(in detail: TournamentDetail) {
        guard !hasDecidedLinkedMatch else { return }
        hasDecidedLinkedMatch = true
        if let id = destination.matchID, detail.match(id: id) != nil { linkedMatchToShow = id }
    }

    /// The view took the linked match to its sheet.
    func consumeLinkedMatch() {
        linkedMatchToShow = nil
    }

    /// One view per screen instance, however often the view's task restarts.
    private func recordViewed(_ tournament: Tournament) {
        guard !hasRecordedView else { return }
        hasRecordedView = true
        recorder.record(.tournamentViewed(tournament, at: now()))
    }

    /// The room is a group under the tournament's id; fetched for the chat, which needs the group as the backend holds it.
    /// Placed in Mine first, as an accepted invite's is: Mine's by-user index may still miss a room just entered, and
    /// the Chats split view shows only rooms Mine lists.
    func openChat() async {
        await perform("Open chat") { [self] in
            let room = try await groupRepository.group(id: destination.id)
            if room.isMember { myGroups.add(room) }
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

    /// One action at a time; the gate repeats a `TRY_AGAIN` once, keeps a dismissed screen quiet, logs a refusal at
    /// warning (an expected product state: the detail was stale) and sends every failure to the popup through the
    /// reporter, so a `TERMS_REQUIRED` raises the terms sheet. Answers whether the work went through, so a sheet can
    /// close on success. Shared with the `+Entries` and `+Matches` files.
    @discardableResult
    func perform(_ action: String, _ work: () async throws -> Void) async -> Bool {
        guard !isBusy, identity.currentUserID != nil else { return false }
        isBusy = true
        defer { isBusy = false }
        return await gate.run("\(action) for tournament \(destination.id)", work)
    }
}

private extension AppError {
    /// The 403, 404 and 409 answers a stale detail earns (registration closed meanwhile, the entry gone, a match not
    /// ready): expected product states, not failures, like `EventDetailViewModel`'s `isParticipationConflict` and
    /// `GroupDetailViewModel`'s `isGroupConflict`.
    var isTournamentRefusal: Bool {
        switch self {
        case .tournamentNotFound, .registrationClosed, .tournamentFull, .alreadyEntered, .teamFull, .entryNotFound,
             .notOrganizer, .tournamentLocked, .notEnoughEntries, .notInMatch, .matchNotReady, .matchNotFound,
             .drawNotAllowed, .tournamentLimit, .tournamentMembershipLimit, .tryAgain, .termsRequired:
            true
        default:
            false
        }
    }
}
