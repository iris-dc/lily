import Foundation
import Testing
@testable import lily

@MainActor
struct MyGroupsStoreTests {
    nonisolated private static let start = Date(timeIntervalSince1970: 1_700_000_000)

    private let repository = FakeGroupRepository()
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let changes = ChangeTracker()
    private let logger = SpyLogger()
    private let errorCenter: ErrorCenter

    init() {
        errorCenter = ErrorCenter(logger: logger)
    }

    private func makeStore(now: @escaping () -> Date = { start }) -> MyGroupsStore {
        MyGroupsStore(repository: repository,
                      identity: identity,
                      changes: changes,
                      errorCenter: errorCenter,
                      logger: logger,
                      now: now)
    }

    /// Two groups in Mine order: the more recently active first.
    private var mine: [SportGroup] {
        [.fixture(id: "a", lastMessageAt: Self.start, role: .member),
         .fixture(id: "b", createdAt: Self.start.addingTimeInterval(-100), role: .admin)]
    }

    @Test func loadIfStaleReusesGroupsUntilTheyExpire() async {
        repository.result = .success(mine)
        var clock = Self.start
        let store = makeStore { clock }

        await store.loadIfStale()
        await store.loadIfStale()
        #expect(repository.requestedScopes == [.mine] && repository.requestedCursors == [nil])
        #expect(store.groups == mine && !store.loadFailed)
        #expect(logger.messages(in: .cache).contains { $0.contains("never loaded") })

        clock = clock.addingTimeInterval(AppConfig.Groups.listStaleAfter)
        await store.loadIfStale()
        #expect(repository.requestedScopes.count == 2)
        #expect(logger.messages(in: .cache).contains { $0.contains("older than TTL") })
    }

    @Test func aChangeElsewhereOrOfCallerMakesTheListStale() async {
        let store = makeStore()
        await store.loadIfStale()

        changes.recordChange()
        await store.loadIfStale()
        #expect(repository.requestedScopes.count == 2)

        identity.currentUserID = "someone-else"
        await store.loadIfStale()
        #expect(repository.requestedScopes.count == 3)
    }

    @Test func aFailureIsReportedAndRetriedOnlyAfterTheCooldown() async {
        repository.result = .failure(.network)
        var clock = Self.start
        let store = makeStore { clock }

        await store.loadIfStale()
        #expect(store.loadFailed && errorCenter.current?.error == .network)
        repository.result = .success(mine)
        await store.loadIfStale()
        #expect(repository.requestedScopes.count == 1)

        clock = clock.addingTimeInterval(AppConfig.Groups.retryAfterFailure)
        await store.loadIfStale()
        #expect(repository.requestedScopes.count == 2 && store.groups == mine && !store.loadFailed)
    }

    @Test func cancellationStaysQuiet() async {
        repository.thrownError = CancellationError()
        let store = makeStore()

        await store.reload()

        #expect(!store.loadFailed && errorCenter.current == nil)
        #expect(logger.messages(in: .groups, at: .debug).contains { $0.contains("cancelled") })
    }

    /// A guest has no groups; asking is pointless, and whatever a previous user left must go.
    @Test func guestsGetAnEmptyListWithoutARequest() async {
        repository.result = .success(mine)
        let store = makeStore()
        await store.reload()
        #expect(store.groups.count == 2)

        identity.currentUserID = nil
        await store.loadIfStale()
        #expect(store.groups.isEmpty && repository.requestedScopes.count == 1)

        await store.reload()
        #expect(repository.requestedScopes.count == 1)
    }

    @Test func concurrentReloadsCollapseIntoOne() async {
        repository.holdsRequests = true
        let store = makeStore()

        let first = Task { await store.reload() }
        await settle(until: { store.isLoading })
        await store.reload()
        repository.releaseRequests()
        await first.value

        #expect(repository.requestedScopes.count == 1 && !store.isLoading)
    }

    /// A joined group shows at once, in the place a reload would give it, and every other screen learns of the change.
    @Test func addInsertsInMineOrderOnceAndRecordsTheChange() async {
        repository.result = .success(mine)
        let store = makeStore()
        await store.reload()
        let version = changes.version
        let newest = SportGroup.fixture(id: "c", lastMessageAt: Self.start.addingTimeInterval(10), role: .member)
        let oldest = SportGroup.fixture(id: "d", createdAt: Self.start.addingTimeInterval(-500), role: .member)

        store.add(newest)
        store.add(oldest)
        store.add(newest)

        #expect(store.groups.map(\.id) == ["c", "a", "b", "d"])
        #expect(changes.version == version + 3)
        await store.loadIfStale()
        #expect(repository.requestedScopes.count == 1, "the store is current for its own changes")
    }

    @Test func replaceUpdatesInPlaceAndDropsAGroupTheCallerLeft() async {
        repository.result = .success(mine)
        let store = makeStore()
        await store.reload()

        store.replace(SportGroup.fixture(id: "a", memberCount: 9, lastMessageAt: Self.start, role: .member))
        #expect(store.groups.first?.memberCount == 9)

        store.replace(SportGroup.fixture(id: "b", role: nil))
        #expect(store.groups.map(\.id) == ["a"])

        store.replace(SportGroup.fixture(id: "a", deletedAt: .now, role: .member))
        #expect(store.groups.isEmpty)
    }

    /// A `group_updated` broadcast has no membership (one payload for every member); the stored one must survive it.
    @Test func applyMergesABroadcastOntoTheStoredMembership() async {
        repository.result = .success([.fixture(id: "a", lastMessageAt: Self.start, role: .admin, hasUnread: true)])
        let store = makeStore()
        await store.reload()
        let version = changes.version

        store.apply(SportGroup.fixture(id: "a", name: "Renamed", memberCount: 9, membersCanInvite: false))
        store.apply(SportGroup.fixture(id: "stranger", name: "Not mine"))

        let group = store.groups.first
        #expect(store.groups.map(\.id) == ["a"] && changes.version == version + 1)
        #expect(group?.name == "Renamed" && group?.memberCount == 9 && group?.membersCanInvite == false)
        #expect(group?.role == .admin && group?.hasUnread == true)
    }

    @Test func removeDropsTheGroupAndRecordsTheChange() async {
        repository.result = .success(mine)
        let store = makeStore()
        await store.reload()
        let version = changes.version

        store.remove(id: "b")

        #expect(store.groups.map(\.id) == ["a"] && changes.version == version + 1)
    }

    @Test func eligibleForEventsFollowsGroupAccess() async {
        repository.result = .success([
            .fixture(id: "member-open", membersCanCreateEvents: true, role: .member),
            .fixture(id: "member-closed", membersCanCreateEvents: false, role: .member),
            .fixture(id: "admin-closed", membersCanCreateEvents: false, role: .admin),
            .fixture(id: "outsider"),
        ])
        let store = makeStore()
        await store.reload()

        #expect(store.eligibleForEvents.map(\.id) == ["member-open", "admin-closed"])
    }

    /// Sign-out clears the list and the freshness, so the next user starts from a real load.
    @Test func signOutClearsTheStoreThroughTheObserverHook() async {
        repository.result = .success(mine)
        let store = makeStore()
        await store.reload()

        store.sessionDidEnd()
        #expect(store.groups.isEmpty && !store.loadFailed)

        await store.loadIfStale()
        #expect(repository.requestedScopes.count == 2)
    }
}
