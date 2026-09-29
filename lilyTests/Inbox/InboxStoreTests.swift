import Foundation
import Testing
@testable import lily

/// Loading, staleness and paging of the inbox store; `InboxStoreReadingTests` covers the marker and live changes.
@MainActor
struct InboxStoreTests {
    nonisolated private static let start = Date(timeIntervalSince1970: 1_800_000_000)

    private let repository = FakeInboxRepository()
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let errorCenter: ErrorCenter

    init() {
        errorCenter = ErrorCenter(logger: logger)
    }

    private func makeStore(now: @escaping () -> Date = { start }) -> InboxStore {
        InboxStore(repository: repository, identity: identity, errorCenter: errorCenter, logger: logger, now: now)
    }

    /// The reminder is the older item, the invite the newer, as their ids say.
    private var items: [InboxItem] { [.reminder(), .invite()] }

    @Test func loadIfStaleReusesItemsUntilTheyExpire() async {
        repository.pages = [.fixture(items), .fixture(items)]
        var clock = Self.start
        let store = makeStore { clock }

        await store.loadIfStale()
        await store.loadIfStale()
        #expect(repository.pageRequests == [FakeInboxRepository.PageRequest(before: nil, limit: AppConfig.Inbox.pageSize)])
        #expect(store.items == items && !store.loadFailed && !store.hasOlder)
        #expect(logger.messages(in: .cache).contains { $0.contains("never loaded") })
        #expect(logger.messages(in: .inbox, at: .info) == ["Loaded 2 inbox items"])

        clock = clock.addingTimeInterval(AppConfig.Inbox.listStaleAfter)
        await store.loadIfStale()
        #expect(repository.pageRequests.count == 2)
        #expect(logger.messages(in: .cache).contains { $0.contains("older than TTL") })
    }

    @Test func aChangeOfCallerMakesTheInboxStale() async {
        let store = makeStore()
        await store.loadIfStale()

        identity.currentUserID = "someone-else"
        await store.loadIfStale()

        #expect(repository.pageRequests.count == 2)
    }

    @Test func aFailureIsReportedAndRetriedOnlyAfterTheCooldown() async {
        repository.pageError = AppError.inboxUnavailable
        var clock = Self.start
        let store = makeStore { clock }

        await store.loadIfStale()
        #expect(store.loadFailed && errorCenter.current?.error == .inboxUnavailable)
        #expect(logger.messages(in: .inbox, at: .error).count == 1)
        repository.pageError = nil
        repository.pages = [.fixture(items)]
        await store.loadIfStale()
        #expect(repository.pageRequests.count == 1)

        clock = clock.addingTimeInterval(AppConfig.Inbox.retryAfterFailure)
        await store.loadIfStale()
        #expect(repository.pageRequests.count == 2 && store.items == items && !store.loadFailed)
    }

    @Test func cancellationStaysQuiet() async {
        repository.pageError = CancellationError()
        let store = makeStore()

        await store.reload()

        #expect(!store.loadFailed && errorCenter.current == nil)
        #expect(logger.messages(in: .inbox, at: .debug).contains { $0.contains("cancelled") })
    }

    /// A guest has no inbox; asking is pointless, and whatever a previous user left must go.
    @Test func guestsGetAnEmptyInboxWithoutARequest() async {
        repository.pages = [.fixture(items)]
        let store = makeStore()
        await store.reload()
        #expect(store.items.count == 2)

        identity.currentUserID = nil
        await store.loadIfStale()
        #expect(store.items.isEmpty && !store.hasUnread && repository.pageRequests.count == 1)

        await store.reload()
        #expect(repository.pageRequests.count == 1)
    }

    @Test func concurrentReloadsCollapseIntoOne() async {
        repository.holdsRequests = true
        let store = makeStore()

        let first = Task { await store.reload() }
        await settle(until: { store.isLoading })
        let second = Task { await store.reload() }
        await Task.yield()
        repository.releaseRequests()
        await first.value
        await second.value

        #expect(repository.pageRequests.count == 1 && !store.isLoading)
    }

    /// The earlier page is asked for before the cursor the last page named, lands ahead of what is held without
    /// doubling what both pages carried, and says whether anything new came.
    @Test func loadOlderPrependsTheEarlierPageWithoutDuplicates() async {
        let older = InboxItem.reminder(id: "01J9INBOX00000000000000000")
        repository.pages = [.fixture(items, hasMore: true, nextBefore: items[0].id), .fixture([older, items[0]])]
        let store = makeStore()
        await store.reload()
        #expect(store.hasOlder)

        #expect(await store.loadOlder())

        let expected = FakeInboxRepository.PageRequest(before: items[0].id, limit: AppConfig.Inbox.pageSize)
        #expect(repository.pageRequests.last == expected)
        #expect(store.items == [older] + items && !store.hasOlder)
        #expect(await store.loadOlder() == false, "nothing before the oldest item")
        #expect(repository.pageRequests.count == 2)
    }

    @Test func aFailedOlderPageIsReportedAndLeavesTheItems() async {
        repository.pages = [.fixture(items, hasMore: true)]
        let store = makeStore()
        await store.reload()
        repository.pageError = AppError.network

        #expect(await store.loadOlder() == false)

        #expect(store.items == items && store.hasOlder && errorCenter.current?.error == .network)
        #expect(repository.pageRequests.last?.before == items[0].id, "without a cursor the oldest id held is the anchor")
    }

    /// The newest page is the truth: a reload after paging back keeps only what it answers.
    @Test func aReloadReplacesWhatIsHeldWithTheNewestPage() async {
        let older = InboxItem.reminder(id: "01J9INBOX00000000000000000")
        repository.pages = [.fixture(items, hasMore: true), .fixture([older]), .fixture(items, hasMore: true)]
        let store = makeStore()
        await store.reload()
        await store.loadOlder()
        #expect(store.items.count == 3)

        await store.reload()

        #expect(store.items == items && store.hasOlder)
    }

    /// A sign-out while a page is in flight: the answer is the previous user's and must not repopulate a guest's store.
    @Test func anAnswerForAPreviousCallerIsDropped() async {
        repository.pages = [.fixture(items)]
        repository.holdsRequests = true
        let store = makeStore()

        let load = Task { await store.reload() }
        await settle(until: { store.isLoading })
        identity.currentUserID = nil
        store.sessionDidEnd()
        repository.releaseRequests()
        await load.value

        #expect(store.items.isEmpty && !store.isLoading)
        #expect(logger.messages(in: .cache, at: .debug).contains { $0.contains("previous caller") })
    }

    @Test func signOutClearsTheStoreThroughTheObserverHook() async {
        repository.pages = [.fixture(items, hasMore: true, lastReadId: items[1].id), .fixture(items)]
        let store = makeStore()
        await store.reload()
        #expect(!store.hasUnread && store.hasOlder)

        store.sessionDidEnd()
        #expect(store.items.isEmpty && !store.hasOlder && store.lastReadID == nil && !store.loadFailed)

        await store.loadIfStale()
        #expect(repository.pageRequests.count == 2, "the next user starts from a real load")
    }
}
