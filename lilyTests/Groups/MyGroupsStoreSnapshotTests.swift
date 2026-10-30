import Foundation
import Testing
@testable import lily

/// Mine starts from the snapshot the last run left for the caller, which is no load, and keeps every change as the next one.
@MainActor
struct MyGroupsStoreSnapshotTests {
    private let repository = FakeGroupRepository()
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let snapshots = InMemoryListSnapshotStore()
    private let logger = SpyLogger()
    private let held = [SportGroup.fixture(id: "held", role: .member), .fixture(id: "room", role: .member, kind: .direct)]
    private let fresh = [SportGroup.fixture(id: "fresh", role: .admin)]
    private let key = ListSnapshotKey(list: "groups-mine", userID: TestFixtures.user.id)

    private func makeStore() -> MyGroupsStore {
        MyGroupsStore(repository: repository,
                      identity: identity,
                      changes: ChangeTracker(),
                      errorCenter: ErrorCenter(logger: logger),
                      logger: logger,
                      snapshots: snapshots)
    }

    @Test func startsFromTheSnapshotWithoutCountingItAsALoad() async {
        snapshots.seed(held, for: key)
        repository.result = .success(fresh)
        let store = makeStore()
        #expect(store.groups == held && store.communities == [held[0]])
        #expect(!store.hasLoaded && !store.isLoading && store.loadVersion == 0 && snapshots.saveCount == 0)

        await store.loadIfStale()

        #expect(repository.requestedScopes == [.mine] && store.hasLoaded && store.loadVersion == 1)
        #expect(store.groups == fresh && snapshots.load([SportGroup].self, for: key) == fresh)
    }

    @Test func everyLocalChangeIsKeptAsTheSnapshot() {
        let store = makeStore()
        let joined = SportGroup.fixture(id: "joined", role: .member)

        store.add(joined)
        #expect(snapshots.load([SportGroup].self, for: key) == [joined])

        store.remove(id: joined.id)
        #expect(snapshots.load([SportGroup].self, for: key)?.isEmpty == true)
    }

    /// Mine is the caller's: a snapshot of theirs is never another caller's first frame.
    @Test func theSnapshotIsTheCallersOwn() {
        snapshots.seed(held, for: key)
        identity.currentUserID = "someone-else"
        #expect(makeStore().groups.isEmpty)

        identity.currentUserID = TestFixtures.user.id
        #expect(makeStore().groups == held)
    }

    /// A change with more than one step (a room moved by a message, a load keeping a later last message) is one write.
    @Test func eachChangeIsOneWrite() async {
        let room = SportGroup.fixture(id: "room",
                                      lastMessageId: "m1",
                                      lastMessageAt: Date(timeIntervalSince1970: 1_800_000_000),
                                      role: .member)
        repository.result = .success([.fixture(id: "a", role: .member), room])
        let store = makeStore()
        await store.loadIfStale()
        #expect(snapshots.saveCount == 1)

        store.noteMessage(.fixture(id: "m2", sentAt: Date(timeIntervalSince1970: 1_800_000_100)), in: room.id)
        #expect(snapshots.saveCount == 2 && store.groups.first?.id == room.id)

        store.add(.fixture(id: "b", role: .member))
        #expect(snapshots.saveCount == 3)

        await store.reload()
        #expect(snapshots.saveCount == 4 && store.groups.first?.id == room.id)
    }

    /// A guest has no Mine: the clearing a signed-out run does leaves no empty snapshot behind.
    @Test func aGuestKeepsNoSnapshot() async {
        let store = makeStore()
        store.add(.fixture(id: "joined", role: .member))
        identity.currentUserID = nil

        await store.loadIfStale()

        #expect(store.groups.isEmpty && snapshots.storedFiles == [key.fileName])
    }
}
