import Foundation
import Testing
@testable import lily

/// The read marker and the live changes of the inbox store; `InboxStoreTests` covers loading and paging.
@MainActor
struct InboxStoreReadingTests {
    private let repository = FakeInboxRepository()
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let errorCenter: ErrorCenter

    init() {
        errorCenter = ErrorCenter(logger: logger)
    }

    private func makeStore() -> InboxStore {
        InboxStore(repository: repository, identity: identity, errorCenter: errorCenter, logger: logger)
    }

    private var items: [InboxItem] { [.reminder(), .invite()] }

    /// A load ends with a snapshot of the marker; the dot shows while the newest item is newer than it.
    @Test func hasUnreadFollowsTheNewestIdAndTheMarker() async {
        repository.pages = [.fixture(items), .fixture(items, lastReadId: items[0].id), .fixture(items, lastReadId: items[1].id)]
        let store = makeStore()
        #expect(!store.hasUnread, "nothing loaded, nothing unread")

        await store.reload()
        #expect(store.hasUnread && store.lastReadID == nil)
        await store.reload()
        #expect(store.hasUnread && store.lastReadID == items[0].id, "the reminder was read, the invite was not")
        await store.reload()
        #expect(!store.hasUnread)
    }

    /// The dot goes at once and the backend hears once per newest id; a second look sends nothing until a newer item.
    @Test func markReadPutsTheNewestIdOnceAndClearsTheDot() async {
        repository.pages = [.fixture(items)]
        let store = makeStore()
        await store.reload()

        await store.markRead()
        await store.markRead()
        #expect(repository.readMarks == [items[1].id] && !store.hasUnread && store.lastReadID == items[1].id)

        let newer = InboxItem.invite(id: "01J9INBOX00000000000000009")
        store.apply(newer)
        #expect(store.hasUnread)
        await store.markRead()
        #expect(repository.readMarks == [items[1].id, newer.id] && !store.hasUnread)
    }

    @Test func markReadWithoutItemsOrACallerSendsNothing() async {
        let store = makeStore()
        await store.markRead()
        store.apply(.invite())
        identity.currentUserID = nil
        await store.markRead()

        #expect(repository.readMarks.isEmpty)
    }

    /// The marker is a courtesy to the backend: a refusal is logged, and the dot stays cleared.
    @Test func aFailedReadMarkerIsLoggedNotShown() async {
        repository.pages = [.fixture(items)]
        repository.readMarkerError = AppError.network
        let store = makeStore()
        await store.reload()

        await store.markRead()

        #expect(!store.hasUnread && errorCenter.current == nil)
        #expect(logger.messages(in: .inbox, at: .warning).count == 1)
    }

    /// A newer snapshot of the marker is taken, an older one never moves it back.
    @Test func theSnapshotMarkerNeverMovesTheLocalOneBack() async {
        repository.pages = [.fixture(items), .fixture(items, lastReadId: items[0].id)]
        let store = makeStore()
        await store.reload()
        await store.markRead()

        await store.reload()

        #expect(store.lastReadID == items[1].id && !store.hasUnread)
    }

    /// A live item lands in id order, and a repeat with a moved status replaces rather than doubles.
    @Test func applyInsertsInIdOrderAndReplacesByID() async {
        repository.pages = [.fixture(items)]
        let store = makeStore()
        await store.reload()

        let between = InboxItem.reminder(id: "01J9INBOX00000000000000001A")
        let newest = InboxItem.invite(id: "01J9INBOX00000000000000003")
        store.apply(newest)
        store.apply(between)
        store.apply(newest.responding(.accepted, at: .now))

        #expect(store.items.map(\.id) == [items[0].id, between.id, items[1].id, newest.id])
        #expect(store.items.last?.invite?.status == .accepted)
        #expect(logger.messages(in: .inbox, at: .debug).contains("Inbox item \(newest.id) arrived (group_invite)"))
    }

    /// A store that never loaded still takes a live item, so the badge can light up before the tab was visited.
    @Test func applyWorksBeforeTheFirstLoad() {
        let store = makeStore()

        store.apply(.invite())

        #expect(store.items.count == 1 && store.hasUnread)
    }

    @Test func replaceChangesAHeldItemAndIgnoresAStranger() async {
        repository.pages = [.fixture(items)]
        let store = makeStore()
        await store.reload()

        store.replace(items[1].responding(.declined, at: .now))
        store.replace(.invite(id: "stranger"))

        #expect(store.items.map(\.id) == items.map(\.id))
        #expect(store.items[1].invite?.status == .declined)
    }
}
