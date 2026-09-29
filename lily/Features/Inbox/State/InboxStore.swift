import Foundation
import Observation

/// The caller's inbox (the pinned conversation on the Chats tab), kept for the app's lifetime because the tab badge
/// and the Chats row need it before the screen was ever opened. Follows `MyGroupsStore`: the lists' staleness rules
/// through `ContentFreshness`, one request at a time through `SingleFlight`, answers for a previous caller dropped,
/// everything cleared on sign-out. Items are ascending by id (server ULIDs), so the newest is the last.
@Observable
final class InboxStore: SessionObserver {
    private(set) var items: [InboxItem] = []
    /// An earlier page exists before the oldest item held.
    private(set) var hasOlder = false
    private(set) var isLoadingOlder = false
    /// The newest item the caller has seen, as the backend holds it or as `markRead()` just moved it.
    private(set) var lastReadID: String?
    private let load = SingleFlight()
    private var freshness = ContentFreshness(staleAfter: AppConfig.Inbox.listStaleAfter,
                                             retryAfterFailure: AppConfig.Inbox.retryAfterFailure)
    /// The id to page before for the earlier page, when the last page named one.
    private var olderCursor: String?
    /// No sibling screen changes the inbox, so its freshness is judged against one fixed version.
    private static let contentVersion = 0

    private let repository: any InboxRepository
    private let identity: any IdentityProvider
    private let errorCenter: ErrorCenter
    private let logger: any Logging
    private let now: () -> Date

    init(repository: any InboxRepository,
         identity: any IdentityProvider,
         errorCenter: ErrorCenter,
         logger: any Logging,
         now: @escaping () -> Date = { .now }) {
        self.repository = repository
        self.identity = identity
        self.errorCenter = errorCenter
        self.logger = logger
        self.now = now
    }

    /// True from a failed load until the next successful one.
    var loadFailed: Bool { freshness.loadFailed }
    var isLoading: Bool { load.isRunning }
    /// The newest item, whatever its kind.
    var newest: InboxItem? { items.last }
    /// The newest item this build can draw, for the Chats row's caption.
    var newestVisible: InboxItem? { items.last(where: \.isVisible) }
    /// Whether the newest item is newer than the read marker; drives the row's dot and the tab badge.
    var hasUnread: Bool { newest.map { $0.id > (lastReadID ?? "") } ?? false }

    /// Loads once per `AppConfig.Inbox.listStaleAfter`, or sooner when the caller changed; after a failed load it
    /// waits `AppConfig.Inbox.retryAfterFailure`. A guest has no inbox: it is cleared without a request.
    func loadIfStale() async {
        guard let userID = identity.currentUserID else {
            clear()
            return
        }
        guard !freshness.isWaitingToRetry(now: now(), version: Self.contentVersion, userID: userID) else {
            logger.debug(.cache, "Inbox failed to load recently; not retrying yet")
            return
        }
        guard let reason = freshness.stalenessReason(now: now(), version: Self.contentVersion, userID: userID) else {
            logger.debug(.cache, "Inbox is fresh; skipping reload")
            return
        }
        logger.debug(.cache, "Inbox is stale (\(reason)); reloading")
        await reload()
    }

    /// Always asks the backend (pull-to-refresh). A call made while one is in flight joins it; an answer that arrives
    /// after the caller signed out or changed is dropped.
    func reload() async {
        guard let userID = identity.currentUserID else {
            clear()
            return
        }
        await load.run { [self] in await performLoad(for: userID) }
    }

    /// The newest page replaces what is held: the inbox is small, and older pages come back on demand.
    private func performLoad(for userID: String) async {
        do {
            let page = try await repository.page(before: nil, limit: AppConfig.Inbox.pageSize)
            guard identity.isStillCaller(userID, orDrop: "Inbox answer", logger: logger) else { return }
            items = page.items
            hasOlder = page.hasMore
            olderCursor = page.nextBefore
            lastReadID = Self.newer(lastReadID, page.lastReadId)
            freshness.recordSuccess(at: now(), version: Self.contentVersion, userID: userID)
            logger.info(.inbox, "Loaded \(items.count) inbox items")
        } catch {
            guard !AppError.isCancellation(error) else {
                logger.debug(.inbox, "Loading the inbox cancelled")
                return
            }
            guard identity.isStillCaller(userID, orDrop: "Inbox answer", logger: logger) else { return }
            freshness.recordFailure(at: now(), version: Self.contentVersion, userID: userID)
            logger.error(.inbox, "Loading the inbox failed: \(error)")
            errorCenter.report(error)
        }
    }

    /// The page before the oldest item held; answers whether items not held before arrived. Failures reach the popup.
    @discardableResult
    func loadOlder() async -> Bool {
        guard hasOlder, !isLoadingOlder, let userID = identity.currentUserID else { return false }
        guard let anchor = olderCursor ?? items.first?.id else { return false }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let page = try await repository.page(before: anchor, limit: AppConfig.Inbox.pageSize)
            guard identity.isStillCaller(userID, orDrop: "Inbox page", logger: logger) else { return false }
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
        freshness.reset()
    }

    /// The later of two ids in ULID order; `nil` only when both are.
    private static func newer(_ lhs: String?, _ rhs: String?) -> String? {
        switch (lhs, rhs) {
        case (let lhs?, let rhs?): max(lhs, rhs)
        default: lhs ?? rhs
        }
    }
}
