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

    /// A join made while Mine was out: the answer predates it and is applied, so the screen never empties, and the
    /// load runs once more so the backend's view of the join replaces the local one.
    @Test func aLocalAddDuringAMineLoadSurvivesTheAnswer() async {
        repository.result = .success(mine)
        repository.holdsRequests = true
        let store = makeStore()
        let joined = SportGroup.fixture(id: "c", role: .member)

        let load = Task { await store.reload() }
        await settle(until: { repository.requestedScopes.count == 1 })
        store.add(joined)
        repository.releaseRequests()
        repository.holdsRequests = true
        await settle(until: { repository.requestedScopes.count == 2 })
        #expect(store.isLoading, "the first answer was applied and the load runs once more")

        repository.result = .success(mine + [joined])
        repository.releaseRequests()
        await load.value

        #expect(Set(store.groups.map(\.id)) == ["a", "b", "c"] && store.loadVersion == 2 && !store.isLoading)
        #expect(logger.messages(in: .cache, at: .debug).contains { $0.contains("loading once more") })
        await store.loadIfStale()
        #expect(repository.requestedScopes.count == 2, "current after the repeat")
    }

    /// The repeat is bounded: a change landing during it leaves the store stale for the next trigger, never a loop.
    @Test func aChangeDuringTheRepeatWaitsForTheNextTrigger() async {
        repository.result = .success(mine)
        repository.holdsRequests = true
        let store = makeStore()

        let load = Task { await store.reload() }
        await settle(until: { repository.requestedScopes.count == 1 })
        store.add(.fixture(id: "c", role: .member))
        repository.releaseRequests()
        repository.holdsRequests = true
        await settle(until: { repository.requestedScopes.count == 2 })
        store.add(.fixture(id: "d", role: .member))
        repository.releaseRequests()
        await load.value

        #expect(repository.requestedScopes.count == 2 && !store.isLoading, "one repeat, never a loop")
        await store.loadIfStale()
        #expect(repository.requestedScopes.count == 3, "the next trigger reloads over the second change")
    }

    /// A sign-out and sign-in while the previous user's request is still out: the new user's load waits it out instead
    /// of joining it, so the previous user's answer is dropped and theirs is what the store shows.
    @Test func aReloadForANewUserWaitsOutThePreviousUsersRun() async {
        repository.result = .success(mine)
        repository.holdsRequests = true
        let store = makeStore()

        let first = Task { await store.reload() }
        await settle(until: { repository.requestedScopes.count == 1 })
        identity.currentUserID = "someone-else"
        let second = Task { await store.reload() }
        await Task.yield()
        #expect(repository.requestedScopes.count == 1, "the new user waits, nothing runs beside the old request")

        repository.result = .success([.fixture(id: "theirs", role: .member)])
        repository.releaseRequests()
        await first.value
        await second.value

        #expect(repository.requestedScopes.count == 2 && store.groups.map(\.id) == ["theirs"])
        #expect(store.loadVersion == 1 && !store.isLoading)
        #expect(logger.messages(in: .cache, at: .debug).contains { $0.contains("previous caller") })
    }

    /// A change to a group Mine does not hold inserts nothing and says so, while sibling screens still learn of it.
    @Test func replaceOfAGroupNotInMineNeverClaimsAReplace() async {
        repository.result = .success(mine)
        let store = makeStore()
        await store.reload()
        let version = changes.version

        store.replace(.fixture(id: "stranger", role: .member))

        #expect(store.groups.map(\.id) == ["a", "b"] && changes.version == version + 1)
        let lines = logger.messages(in: .cache, at: .debug)
        #expect(lines.contains { $0.contains("Group stranger not in Mine") })
        #expect(!lines.contains { $0.contains("stranger replaced") })
        await store.loadIfStale()
        #expect(repository.requestedScopes.count == 1, "the bump is this store's own")
    }
}
