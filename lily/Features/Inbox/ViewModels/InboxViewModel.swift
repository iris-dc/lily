import Foundation
import Observation

/// The inbox screen: the store's items as rows, Accept / Decline on an invite, the game behind a game reminder, the
/// tournament behind a match reminder and the group behind an ownership notice. The items live in `InboxStore`, which
/// the realtime controller and the Chats row share, so the screen never holds a copy.
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
    private let errorCenter: ErrorCenter
    private let logger: any Logging
    private let tryAgainDelay: Duration
    let now: () -> Date

    init(store: InboxStore,
         repository: any InboxRepository,
         opener: EventOpener,
         myGroups: MyGroupsStore,
         tournamentChanges: ChangeTracker,
         navigation: AppNavigation,
         errorCenter: ErrorCenter,
         logger: any Logging,
         tryAgainDelay: Duration = AppConfig.API.tryAgainDelay,
         now: @escaping () -> Date = { .now }) {
        self.store = store
        self.repository = repository
        self.opener = opener
        self.myGroups = myGroups
        self.tournamentChanges = tournamentChanges
        self.navigation = navigation
        self.errorCenter = errorCenter
        self.logger = logger
        self.tryAgainDelay = tryAgainDelay
        self.now = now
    }

    var rows: [InboxTimelineRow] { InboxTimeline.rows(store.items) }
    var hasOlder: Bool { store.hasOlder }
    var isLoadingOlder: Bool { store.isLoadingOlder }
    var loadFailed: Bool { store.loadFailed }
    /// True until the first page answered or failed, not while the loader's `isLoading` is up: the body renders before
    /// the view's `.task` enters `appear()`, so `isLoading` would show "Nothing here yet" for one commit. Safe to wait
    /// on: `appear()` always starts a load, a guest never reaches the screen, and every load ends in a success or a
    /// failure record.
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

    func loadOlder() async {
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
        await answer(item, verb: "accept", wanting: .accepted) {
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
        await answer(item, verb: "decline", wanting: .declined) {
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

    /// The group an ownership notice names, on Home: the caller owns it now, so Mine holds it — reloaded once when the
    /// notice is newer than the list; a group Mine never learns reaches the popup.
    func openGroup(for item: InboxItem) async {
        guard let payload = item.groupOwnershipTransferred, openingItemID == nil else { return }
        openingItemID = item.id
        defer { openingItemID = nil }
        if !myGroups.groups.contains(where: { $0.id == payload.groupId }) {
            await myGroups.reload()
        }
        guard let group = myGroups.groups.first(where: { $0.id == payload.groupId }) else {
            logger.warning(.inbox, "Notice \(item.id) names group \(payload.groupId), which Mine does not hold")
            errorCenter.report(AppError.groupNotFound)
            return
        }
        logger.info(.inbox, "Notice \(item.id) opened group \(group.id)")
        navigation.open(group: group)
    }

    /// One answer per invite at a time; `TRY_AGAIN` is repeated once. An outcome left unknown (a lost connection, a
    /// 5xx) is read back from the inbox before any popup (`LostAnswer`): a card the backend shows answered as asked
    /// means the tap went through, and an accept then reloads Mine, the one place the new room can surface, since the
    /// page names no group or tournament (a tournament invite's tells the tournament lists too). A verdict on the invite
    /// (answered already, expired) is a stale card, not a fault: a warning, and the same read-back so the card shows
    /// the invite as the backend now has it.
    private func answer(_ item: InboxItem,
                        verb: String,
                        wanting status: InviteStatus,
                        _ attempt: () async throws -> Void) async {
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
            let settled = await inviteReadBack.settle("Invite \(item.id) \(verb)", despite: failure) { items in
                items.first { $0.id == item.id }?.inviteAnswer.map { $0.status == status }
            }
            if settled.isLanded {
                await noteLanded(status, of: item)
                return
            }
            let isVerdict = (failure as? AppError)?.isInviteVerdict == true
            logger.log(isVerdict ? .warning : .error, .inbox, "Invite \(item.id) \(verb) failed: \(failure)")
            errorCenter.report(failure)
        }
    }

    /// A landed accept admitted the caller somewhere the page does not name: Mine is reloaded for the room, and a
    /// tournament's lists are told as a direct accept tells them.
    private func noteLanded(_ status: InviteStatus, of item: InboxItem) async {
        guard status == .accepted else { return }
        if item.kind == .tournamentInvite { tournamentChanges.recordChange() }
        await myGroups.reload()
    }

    /// The store stays the one source: the read-back is its reload, and its failure is the inbox's own.
    private var inviteReadBack: LostAnswer<[InboxItem]> {
        LostAnswer(category: .inbox,
                   logger: logger,
                   leavesOutcomeUnknown: { $0 == .network || $0 == .inviteActionFailed },
                   isWorthAnotherLook: { $0.isInviteVerdict },
                   refetch: { [store] in
                       await store.reload()
                       guard !store.loadFailed else { throw AppError.inboxUnavailable }
                       return store.items
                   },
                   apply: { _ in })
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
