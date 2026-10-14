import Foundation
import Testing
@testable import lily

/// What lands while an inbox request is out: a reload under the earlier page being fetched, a new user under a load.
@MainActor
struct InboxStoreConcurrencyTests {
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

    /// The reminder is the older item, the invite the newer, as their ids say.
    private var items: [InboxItem] { [.reminder(), .invite()] }

    /// A reload that lands while the earlier page is out replaced the items wholesale: the page before the old anchor
    /// is dropped rather than merged around a hole, and Load earlier asks again before the new anchor.
    @Test func anOlderPageAfterAReloadIsDropped() async {
        let older = InboxItem.reminder(id: "01J9INBOX00000000000000000")
        let newer = InboxItem.invite(id: "01J9INBOX00000000000000004")
        repository.pages = [.fixture(items, hasMore: true, nextBefore: items[0].id),
                            .fixture([items[1], newer], hasMore: true, nextBefore: items[1].id),
                            .fixture([older, items[0]])]
        let store = makeStore()
        await store.reload()
        repository.holdsRequests = true

        let earlier = Task { await store.loadOlder() }
        await settle(until: { repository.pageRequests.count == 2 })
        repository.holdsRequests = false
        await store.reload()
        repository.releaseRequests()
        let broughtItems = await earlier.value

        #expect(!broughtItems)
        #expect(store.items == [items[1], newer] && store.hasOlder, "the reloaded page alone, no hole")
        #expect(logger.messages(in: .inbox, at: .debug).contains { $0.contains("dropped") })

        repository.pages = [.fixture([items[0]])]
        let loaded = await store.loadOlder()
        #expect(loaded)
        #expect(repository.pageRequests.last?.before == items[1].id, "Load earlier asks before the new anchor")
        #expect(store.items == [items[0], items[1], newer])
    }

    /// A sign-out and sign-in while the previous user's load is out: the new user's reload waits that run out and then
    /// loads for them, and the old answer is dropped rather than shown to them.
    @Test func anInboxReloadForANewUserWaitsOutThePreviousUsersRun() async {
        repository.pages = [.fixture(items), .fixture([.invite(id: "theirs")])]
        repository.holdsRequests = true
        let store = makeStore()

        let first = Task { await store.reload() }
        await settle(until: { repository.pageRequests.count == 1 })
        identity.currentUserID = "someone-else"
        let second = Task { await store.reload() }
        await Task.yield()
        #expect(repository.pageRequests.count == 1, "the new user waits, nothing runs beside the old request")

        repository.releaseRequests()
        await first.value
        await second.value

        #expect(repository.pageRequests.count == 2 && store.items.map(\.id) == ["theirs"] && !store.isLoading)
        #expect(logger.messages(in: .cache, at: .debug).contains { $0.contains("previous caller") })
    }
}
