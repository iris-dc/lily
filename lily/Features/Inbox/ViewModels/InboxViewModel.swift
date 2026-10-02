import Foundation
import Observation

/// The inbox screen: the store's items as rows, Accept / Decline on an invite, and the game behind a reminder. The
/// items live in `InboxStore`, which the realtime controller and the Chats row share, so the screen never holds a copy.
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
    private let navigation: AppNavigation
    private let reporter: GroupErrorReporter
    private let logger: any Logging
    private let tryAgainDelay: Duration
    let now: () -> Date

    init(store: InboxStore,
         repository: any InboxRepository,
         opener: EventOpener,
         myGroups: MyGroupsStore,
         navigation: AppNavigation,
         reporter: GroupErrorReporter,
         logger: any Logging,
         tryAgainDelay: Duration = AppConfig.API.tryAgainDelay,
         now: @escaping () -> Date = { .now }) {
        self.store = store
        self.repository = repository
        self.opener = opener
        self.myGroups = myGroups
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
    /// True until the first page answered, so the empty state waits for it.
    var isInitialLoad: Bool { store.isLoading && store.items.isEmpty }
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

    /// Joins the group: the item shows as accepted, the group goes into Mine at once, and its chat opens.
    func accept(_ item: InboxItem) async {
        await answer(item, verb: "accept") {
            let acceptance = try await repository.accept(itemID: item.id)
            store.replace(acceptance.item)
            myGroups.add(acceptance.group)
            logger.info(.inbox, "Invite \(item.id) accepted into group \(acceptance.group.id)")
            navigation.open(chat: acceptance.group)
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
        await opener.open(eventID: reminder.eventId, from: "reminder \(item.id)")
    }

    /// One answer per invite at a time; `TRY_AGAIN` is repeated once. A verdict on the invite (answered already,
    /// expired) reloads the inbox after the popup, so the card shows the invite as the backend now has it.
    private func answer(_ item: InboxItem, verb: String, _ attempt: () async throws -> Void) async {
        guard !busyItemIDs.contains(item.id) else { return }
        busyItemIDs.insert(item.id)
        defer { busyItemIDs.remove(item.id) }
        do {
            try await LostRace.attemptTwice(delay: tryAgainDelay, onRetry: { logRetry(item, verb: verb) }, attempt)
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.inbox, "Invite \(item.id) \(verb) failed: \(error)")
            reporter.report(error)
            if let appError = error as? AppError, appError.isInviteVerdict { await store.reload() }
        }
    }

    private func logRetry(_ item: InboxItem, verb: String) {
        logger.info(.inbox, "Invite \(item.id) \(verb) lost a race; retrying once")
    }
}

private extension AppError {
    /// The backend's word on the invite itself: the card is stale and worth another look.
    var isInviteVerdict: Bool {
        self == .inviteNotPending || self == .inviteExpired
    }
}
