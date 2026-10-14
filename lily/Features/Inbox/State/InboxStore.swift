import Foundation
import Observation

/// The caller's inbox (the pinned conversation on the Chats tab), kept for the app's lifetime because the tab badge
/// and the Chats row need it before the screen was ever opened. Loads its newest page through `StoreLoader` like
/// `MyGroupsStore` (the lists' staleness rules, one request at a time, answers for a previous caller dropped), judged
/// against one fixed version because no sibling screen changes the inbox; everything is cleared on sign-out. Items are
/// ascending by id (server ULIDs), so the newest is the last.
@Observable
final class InboxStore: SessionObserver {
    private(set) var items: [InboxItem] = []
    /// An earlier page exists before the oldest item held.
    private(set) var hasOlder = false
    private(set) var isLoadingOlder = false
    /// The newest item the caller has seen, as the backend holds it or as `markRead()` just moved it.
    private(set) var lastReadID: String?
    private let loader: StoreLoader
    /// The id to page before for the earlier page, when the last page named one.
    private var olderCursor: String?

    private let repository: any InboxRepository
    private let identity: any IdentityProvider
    private let errorCenter: ErrorCenter
    private let logger: any Logging

    init(repository: any InboxRepository,
         identity: any IdentityProvider,
         errorCenter: ErrorCenter,
         logger: any Logging,
         now: @escaping () -> Date = { .now }) {
        self.repository = repository
        self.identity = identity
        self.errorCenter = errorCenter
        self.logger = logger
        loader = StoreLoader(noun: "the inbox",
                             category: .inbox,
                             identity: identity,
                             errorCenter: errorCenter,
                             logger: logger,
                             now: now,
                             version: { 0 })
    }

    /// True from a failed load until the next successful one.
    var loadFailed: Bool { loader.loadFailed }
    var isLoading: Bool { loader.isLoading }
    /// A page answered since the last sign-in; the screen shows its spinner until then, whether or not its task has
    /// started the load.
    var hasLoaded: Bool { loader.hasLoaded }
    /// The newest item, whatever its kind.
    var newest: InboxItem? { items.last }
    /// The newest item this build can draw, for the Chats row's caption.
    var newestVisible: InboxItem? { items.last(where: \.isVisible) }
    /// Whether the newest item this build can draw is newer than the read marker; drives the row's dot and the tab
    /// badge. An item of a kind this build does not know lights nothing, because the screen (`InboxTimeline.rows`)
    /// would show nothing new for it; `markRead()` still sends `newest.id`, hidden or not.
    var hasUnread: Bool { newestVisible.map { $0.id > (lastReadID ?? "") } ?? false }

    /// Loads once per `AppConfig.Lists.staleAfter`, or sooner when the caller changed; after a failed load it
    /// waits `AppConfig.Lists.retryAfterFailure`. A guest has no inbox: it is cleared without a request.
    func loadIfStale() async {
        guard identity.currentUserID != nil else {
            clear()
            return
        }
        await loader.loadIfStale(fetch: fetchNewestPage, apply: applyNewestPage)
    }

    /// Always asks the backend (pull-to-refresh). A call made while one is in flight for the same user joins it; one
    /// for another user (a sign-out and sign-in while the previous user's request is still out) waits it out and then
    /// loads for them; an answer that arrives after the caller signed out or changed is dropped.
    func reload() async {
        guard identity.currentUserID != nil else {
            clear()
            return
        }
        await loader.reload(fetch: fetchNewestPage, apply: applyNewestPage)
    }

    private func fetchNewestPage() async throws -> InboxPage {
        try await repository.page(before: nil, limit: AppConfig.Inbox.pageSize)
    }

    /// The newest page replaces what is held: the inbox is small, and older pages come back on demand.
    private func applyNewestPage(_ page: InboxPage) {
        items = page.items
        hasOlder = page.hasMore
        olderCursor = page.nextBefore
        lastReadID = Self.newer(lastReadID, page.lastReadId)
        logger.info(.inbox, "Loaded \(items.count) inbox items")
    }

    /// The page before the oldest item held; answers whether items not held before arrived. Failures reach the popup.
    /// A reload landing while the page was out (pull-to-refresh, the Chats row, the shell's sync) replaced the items
    /// wholesale, so a page before the old anchor would leave a hole and point the cursor past it: it is dropped, and
    /// Load earlier asks again before the new anchor.
    @discardableResult
    func loadOlder() async -> Bool {
        guard hasOlder, !isLoadingOlder, let userID = identity.currentUserID else { return false }
        guard let anchor = olderCursor ?? items.first?.id else { return false }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let page = try await repository.page(before: anchor, limit: AppConfig.Inbox.pageSize)
            guard identity.isStillCaller(userID, orDrop: "Inbox page", logger: logger) else { return false }
            guard (olderCursor ?? items.first?.id) == anchor else {
                logger.debug(.inbox, "Earlier inbox page dropped: the newest page moved meanwhile")
                return false
            }
            let held = Set(items.map(\.id))
            let fresh = page.items.filter { !held.contains($0.id) }
            items = (fresh + items).sorted { $0.id < $1.id }
            hasOlder = page.hasMore
            olderCursor = page.nextBefore
            logger.debug(.inbox, "Loaded \(fresh.count) earlier inbox items")
            return !fresh.isEmpty
        } catch {
            guard !AppError.isCancellation(error) else { return false }
            logger.error(.inbox, "Loading earlier inbox items failed: \(error)")
            errorCenter.report(error)
            return false
        }
    }

    /// A live `inbox_item`: replaces the item when held (a status the backend moved), inserts it in id order otherwise.
    func apply(_ item: InboxItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            logger.debug(.inbox, "Inbox item \(item.id) updated live")
        } else {
            items.insert(item, at: items.firstIndex { $0.id > item.id } ?? items.endIndex)
            logger.debug(.inbox, "Inbox item \(item.id) arrived (\(item.kind.wireName))")
        }
    }

    /// The item as an accept or a decline just answered it; one not held (a page that moved on) is left out.
    func replace(_ item: InboxItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
    }

    /// The caller has seen the inbox: the dot goes at once, and the backend hears once per newer newest id. A refused
    /// PUT is a warning, never a popup; the marker is sent again when a newer item arrives.
    func markRead() async {
        guard let newest, let userID = identity.currentUserID, newest.id > (lastReadID ?? "") else { return }
        lastReadID = newest.id
        do {
            let marker = try await repository.markRead(itemID: newest.id)
            guard identity.isStillCaller(userID, orDrop: "Inbox read marker", logger: logger) else { return }
            lastReadID = Self.newer(lastReadID, marker)
            logger.debug(.inbox, "Inbox read marker moved to \(newest.id)")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.warning(.inbox, "Inbox read marker failed: \(error)")
        }
    }

    func sessionDidEnd() {
        clear()
        logger.debug(.cache, "Inbox cleared on sign-out")
    }

    private func clear() {
        items = []
        hasOlder = false
        olderCursor = nil
        lastReadID = nil
        loader.reset()
    }

    /// The later of two ids in ULID order; `nil` only when both are.
    private static func newer(_ lhs: String?, _ rhs: String?) -> String? {
        switch (lhs, rhs) {
        case (let lhs?, let rhs?): max(lhs, rhs)
        default: lhs ?? rhs
        }
    }
}
