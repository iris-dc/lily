import Foundation
import Observation

/// The inbox screen: the store's items as rows, Accept / Decline on an invite, the game behind a game reminder and
/// the tournament behind a match reminder. The items live in `InboxStore`, which the realtime controller and the Chats
/// row share, so the screen never holds a copy.
@Observable
final class InboxViewModel {
    let store: InboxStore
    /// Invites with an answer in flight; their buttons disable themselves.
    private(set) var busyItemIDs: Set<String> = []
    /// The reminder whose game is being fetched.
    private(set) var openingItemID: String?

    private let repository: any InboxRepository
    private let opener: EventOpener
    private let myGroups: MyGroupsStore
    private let tournamentChanges: ChangeTracker
    private let navigation: AppNavigation
    private let reporter: GroupErrorReporter
    private let logger: any Logging
    private let tryAgainDelay: Duration
    let now: () -> Date

    init(store: InboxStore,
         repository: any InboxRepository,
         opener: EventOpener,
         myGroups: MyGroupsStore,
         tournamentChanges: ChangeTracker,
         navigation: AppNavigation,
         reporter: GroupErrorReporter,
         logger: any Logging,
         tryAgainDelay: Duration = AppConfig.API.tryAgainDelay,
         now: @escaping () -> Date = { .now }) {
        self.store = store
        self.repository = repository
        self.opener = opener
        self.myGroups = myGroups
        self.tournamentChanges = tournamentChanges
        self.navigation = navigation
        self.reporter = reporter
        self.logger = logger
        self.tryAgainDelay = tryAgainDelay
        self.now = now
    }

    var rows: [InboxTimelineRow] { InboxTimeline.rows(store.items) }
    var hasOlder: Bool { store.hasOlder }
    var isLoadingOlder: Bool { store.isLoadingOlder }
    var loadFailed: Bool { store.loadFailed }
    /// True until the first page answered or failed. Judging by `isLoading` instead shows "Nothing here yet" for one
    /// commit before the spinner, because the body renders before the view's `.task` has entered `appear()`. Safe to
    /// wait on: `appear()` always starts a load, a guest never reaches the screen, and every load ends in a success or
    /// a failure record.
    var isInitialLoad: Bool { !store.hasLoaded && !store.loadFailed }
    /// The newest item's id; the screen watches it to mark a live arrival read while open.
    var newestID: String? { store.newest?.id }

    func isBusy(_ item: InboxItem) -> Bool {
        busyItemIDs.contains(item.id) || openingItemID == item.id
    }

    /// The screen appeared: what is there is shown and counted as read.
    func appear() async {
        await store.loadIfStale()
        await store.markRead()
    }

    /// Pull-to-refresh.
    func refresh() async {
        await store.reload()
        await store.markRead()
    }

    @discardableResult
    func loadOlder() async -> Bool {
        await store.loadOlder()
    }

    /// A new item landed while the inbox is open: it was seen.
    func noteNewItems() async {
        await store.markRead()
    }

    /// Accepts: the item shows as accepted; a group goes into Mine at once and its chat opens; a tournament's lists
    /// reload and its detail opens (Mine reloaded first when the accept entered the caller, so their new room is
    /// listed; a team tournament leaves them to pick or name a team). An acceptance naming neither (contract drift)
    /// still admitted the caller somewhere, so Mine is reloaded, the one place a new room can surface; nothing opens
    /// and no popup shows.
    func accept(_ item: InboxItem) async {
        await answer(item, verb: "accept") {
            let acceptance = try await repository.accept(itemID: item.id)
            store.replace(acceptance.item)
            if let group = acceptance.group {
                myGroups.add(group)
                logger.info(.inbox, "Invite \(item.id) accepted into group \(group.id)")
                navigation.open(chat: group)
            } else if let tournament = acceptance.tournament {
                tournamentChanges.recordChange()
                let entry = tournament.myEntryId.map { " as entry \($0)" } ?? ""
                logger.info(.inbox, "Invite \(item.id) accepted into tournament \(tournament.id)\(entry)")
                if tournament.hasEntered { await myGroups.reload() }
                navigation.open(tournament: tournament.destination)
            } else {
                logger.warning(.inbox, "Invite \(item.id) accepted into nothing this build knows; reloading Mine")
                await myGroups.reload()
            }
        }
    }

    func decline(_ item: InboxItem) async {
        await answer(item, verb: "decline") {
            store.replace(try await repository.decline(itemID: item.id))
            logger.info(.inbox, "Invite \(item.id) declined")
        }
    }

    /// The game a reminder points at, pushed on the Chats stack; a game that is gone or unreachable reaches the popup.
    func openEvent(for item: InboxItem) async {
        guard let reminder = item.reminder, openingItemID == nil else { return }
        openingItemID = item.id
        defer { openingItemID = nil }
        let opened = await opener.open(eventID: reminder.eventId, from: "reminder \(item.id)")
        if opened { logger.info(.inbox, "Reminder \(item.id) opened game \(reminder.eventId)") }
    }

    /// The tournament a match reminder points at, pushed on the Chats stack with that match's sheet up; the card
    /// carries the name, so nothing is fetched here (the detail is).
    func openTournament(for item: InboxItem) {
        guard let reminder = item.matchReminder else { return }
        logger.info(.inbox, "Reminder \(item.id) opened match \(reminder.matchId) of tournament \(reminder.tournamentId)")
        navigation.openInChat(reminder.destination)
    }

    /// One answer per invite at a time; `TRY_AGAIN` is repeated once. A verdict on the invite (answered already,
    /// expired) is a stale card, not a fault: a warning, and the inbox is reloaded after the popup so the card shows
    /// the invite as the backend now has it.
    private func answer(_ item: InboxItem, verb: String, _ attempt: () async throws -> Void) async {
        guard !busyItemIDs.contains(item.id) else { return }
        busyItemIDs.insert(item.id)
        defer { busyItemIDs.remove(item.id) }
        do {
            try await LostRace.attemptTwice(delay: tryAgainDelay,
                                            logger: logger,
                                            category: .inbox,
                                            retrying: "Invite \(item.id) \(verb)",
                                            attempt)
        } catch {
            guard !AppError.isCancellation(error) else { return }
            let failure = Self.restated(error, for: item)
            let isVerdict = (failure as? AppError)?.isInviteVerdict == true
            logger.log(isVerdict ? .warning : .error, .inbox, "Invite \(item.id) \(verb) failed: \(failure)")
            reporter.report(failure)
            if isVerdict { await store.reload() }
        }
    }

    /// The inbox route answers the groups cap and the tournaments cap under one code; the card knows which it is.
    private static func restated(_ error: any Error, for item: InboxItem) -> any Error {
        guard item.kind == .tournamentInvite, error as? AppError == .membershipLimitReached else { return error }
        return AppError.tournamentMembershipLimit
    }
}

private extension AppError {
    /// The backend's word on the invite itself: the card is stale and worth another look.
    var isInviteVerdict: Bool {
        self == .inviteNotPending || self == .inviteExpired
    }
}
