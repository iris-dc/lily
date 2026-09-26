import Foundation
import Testing
@testable import lily

/// What a load answers for whom; `MyGroupsStoreTests` is at the type-body limit.
@MainActor
struct MyGroupsStoreCallerTests {
    private let repository = FakeGroupRepository()
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let changes = ChangeTracker()
    private let logger = SpyLogger()
    private let errorCenter: ErrorCenter

    init() {
        errorCenter = ErrorCenter(logger: logger)
    }

    private func makeStore() -> MyGroupsStore {
        MyGroupsStore(repository: repository, identity: identity, changes: changes, errorCenter: errorCenter, logger: logger)
    }

    private var mine: [SportGroup] { [.fixture(id: "a", role: .member), .fixture(id: "b", role: .admin)] }

    /// A sign-out while Mine is in flight: the answer is the previous user's and must not repopulate a guest's store.
    @Test func anAnswerForAPreviousCallerIsDropped() async {
        repository.result = .success(mine)
        repository.holdsRequests = true
        let store = makeStore()

        let load = Task { await store.reload() }
        await settle(until: { store.isLoading })
        identity.currentUserID = nil
        store.sessionDidEnd()
        repository.releaseRequests()
        await load.value

        #expect(store.groups.isEmpty && store.loadVersion == 0 && !store.isLoading)
        #expect(logger.messages(in: .cache, at: .debug).contains { $0.contains("previous caller") })
    }

    /// Nor is a failure the previous user's request met recorded against, or shown to, whoever is there now.
    @Test func aFailureForAPreviousCallerIsNeitherRecordedNorShown() async {
        repository.result = .failure(.network)
        repository.holdsRequests = true
        let store = makeStore()

        let load = Task { await store.reload() }
        await settle(until: { store.isLoading })
        identity.currentUserID = "someone-else"
        repository.releaseRequests()
        await load.value

        #expect(!store.loadFailed && errorCenter.current == nil)
        #expect(logger.messages(in: .groups, at: .error).isEmpty)
    }

    /// The shell cancels its sync when the scene phase changes while Mine is in flight and starts another: the request
    /// is the store's own task, so it lands, and the new run joins it instead of being dropped.
    @Test func aCancelledCallerNeitherLosesTheLoadNorDropsTheNextOne() async {
        repository.result = .success(mine)
        repository.holdsRequests = true
        let store = makeStore()

        let cancelled = Task { await store.reload() }
        await settle(until: { repository.requestedScopes.count == 1 })
        cancelled.cancel()
        let replacement = Task { await store.loadIfStale() }
        await Task.yield()
        repository.releaseRequests()
        await cancelled.value
        await replacement.value

        #expect(store.groups.count == 2 && store.loadVersion == 1 && !store.isLoading)
        #expect(repository.requestedScopes.count == 1)
    }

    /// The unread set follows loads alone; a local change carries membership flags older than the rooms.
    @Test func onlyALoadBumpsTheLoadVersion() async {
        repository.result = .success(mine)
        let store = makeStore()

        await store.reload()
        #expect(store.loadVersion == 1)

        store.add(.fixture(id: "c", role: .member))
        store.replace(.fixture(id: "a", memberCount: 9, role: .member))
        store.apply(.fixture(id: "b", name: "Renamed"))
        store.remove(id: "c")
        #expect(store.loadVersion == 1)

        repository.result = .failure(.network)
        await store.reload()
        #expect(store.loadVersion == 1)

        repository.result = .success(mine)
        await store.reload()
        #expect(store.loadVersion == 2)
    }
}
