import Testing
@testable import lily

/// Home's Groups segment reads the store's own `listState`: the snapshot-seed fold the two list view models pin for
/// themselves, judged on `communities` because that is what the pane draws.
@MainActor
struct MyGroupsStoreListStateTests {
    private let repository = FakeGroupRepository()
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let snapshots = InMemoryListSnapshotStore()
    private let logger = SpyLogger()
    private let key = ListSnapshotKey(list: "groups-mine", userID: TestFixtures.user.id)

    private func makeStore() -> MyGroupsStore {
        MyGroupsStore(repository: repository,
                      identity: identity,
                      changes: ChangeTracker(),
                      errorCenter: ErrorCenter(logger: logger),
                      logger: logger,
                      snapshots: snapshots)
    }

    @Test func spinsUntilTheFirstAnswerWhenThereIsNoSnapshot() {
        let store = makeStore()
        #expect(store.isInitialLoad && store.listState == .loading)
    }

    /// Dropping the failure from the fold would spin forever: a failed first load must say so.
    @Test func aFailedFirstLoadSaysSoInsteadOfSpinningForever() async {
        repository.result = .failure(.network)
        let store = makeStore()
        await store.loadIfStale()
        #expect(!store.isInitialLoad && store.listState == .failed)
    }

    @Test func anEmptyAnswerIsTheEmptyHint() async {
        repository.result = .success([])
        let store = makeStore()
        await store.loadIfStale()
        #expect(store.listState == .empty)
    }

    @Test func aLoadedListIsContent() async {
        repository.result = .success([.fixture(id: "a", role: .member)])
        let store = makeStore()
        await store.loadIfStale()
        #expect(store.listState == .content)
    }

    /// The pane draws communities: conversations and rooms alone leave the segment empty.
    @Test func conversationsAloneAreNotContent() async {
        repository.result = .success([.fixture(id: "direct", role: .member, kind: .direct)])
        let store = makeStore()
        await store.loadIfStale()
        #expect(store.listState == .empty)
    }

    /// An empty stored snapshot is an answer the screen can show: the hint from the first frame, never a spinner.
    @Test func anEmptySnapshotIsTheEmptyStateFromTheFirstFrame() {
        snapshots.seed([SportGroup](), for: key)
        let store = makeStore()
        #expect(!store.isInitialLoad && store.listState == .empty)
    }

    @Test func aHeldSnapshotIsContentBeforeAnyLoad() {
        snapshots.seed([SportGroup.fixture(id: "held", role: .member)], for: key)
        #expect(makeStore().listState == .content)
    }
}
