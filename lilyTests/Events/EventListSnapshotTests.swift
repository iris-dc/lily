import Foundation
import Testing
@testable import lily

/// The list starts from the snapshot the last run left for the caller and keeps every change as the next one, so a
/// tab's first frame shows content while the first load is out.
@MainActor
struct EventListSnapshotTests {
    private let repository = FakeEventRepository()
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let snapshots = InMemoryListSnapshotStore()
    private let logger = SpyLogger()
    private let held = [SportEvent.fixture(id: "held", startsAt: Date(timeIntervalSince1970: 1_800_000_000))]
    private let fresh = [SportEvent.fixture(id: "fresh", startsAt: Date(timeIntervalSince1970: 1_800_003_600))]
    private let key = ListSnapshotKey(list: "events-upcoming", userID: TestFixtures.user.id)

    private func makeViewModel(scope: EventScope = .upcoming) -> EventListViewModel {
        makeEventListViewModel(scope: scope, repository: repository, identity: identity, logger: logger, snapshots: snapshots)
    }

    private func screenState(of viewModel: EventListViewModel) -> EventListScreenState {
        .resolve(isInitialLoad: viewModel.isInitialLoad,
                 loadFailed: viewModel.loadFailed,
                 hasEvents: !viewModel.events.isEmpty,
                 isEverythingFilteredOut: viewModel.isEverythingFilteredOut,
                 awaitsAnswerForPosition: viewModel.awaitsAnswerForPosition)
    }

    /// The snapshot is content on the first frame and through the first load, which still runs: it is a hint, not an answer.
    @Test func startsFromTheSnapshotAndShowsItWhileTheFirstLoadIsOut() async {
        snapshots.seed(held, for: key)
        repository.result = .success(fresh)
        repository.holdsRequests = true
        let viewModel = makeViewModel()
        #expect(viewModel.events == held && !viewModel.hasLoaded && viewModel.listState == .content)

        let load = Task { await viewModel.loadIfStale() }
        await settle(until: { repository.requestedScopes.count == 1 })
        #expect(viewModel.isLoading && !viewModel.isInitialLoad && viewModel.listState == .content)
        #expect(screenState(of: viewModel) == .list)
        #expect(viewModel.events == held)

        repository.releaseRequests()
        await load.value
        #expect(viewModel.events == fresh && viewModel.hasLoaded)
        #expect(snapshots.load([SportEvent].self, for: key) == fresh)
        #expect(logger.messages(in: .cache).contains { $0.contains("never loaded") })
    }

    /// An empty answer kept from the last launch is content too: "nothing yet" from the first frame, kept through the
    /// reload, where a spinner between the two readings of the same words looked like a glitch on the phone.
    @Test func anEmptySnapshotSaysNothingYetFromTheFirstFrameAndThroughTheReload() async {
        snapshots.seed([SportEvent](), for: key)
        repository.result = .success([])
        repository.holdsRequests = true
        let viewModel = makeViewModel()
        #expect(!viewModel.isInitialLoad && viewModel.listState == .empty && screenState(of: viewModel) == .empty)

        let load = Task { await viewModel.loadIfStale() }
        await settle(until: { repository.requestedScopes.count == 1 })
        #expect(viewModel.isLoading && !viewModel.isInitialLoad && screenState(of: viewModel) == .empty)

        repository.releaseRequests()
        await load.value
        #expect(viewModel.hasLoaded && screenState(of: viewModel) == .empty)

        viewModel.clear()
        #expect(viewModel.isInitialLoad && viewModel.listState == .loading, "the next caller has no snapshot")
    }

    /// Without a snapshot nothing changes: the spinner through the first load, the answer kept for the next launch.
    @Test func withoutASnapshotTheFirstLoadShowsTheSpinnerAndIsKept() async {
        repository.result = .success(fresh)
        repository.holdsRequests = true
        let viewModel = makeViewModel()
        #expect(viewModel.events.isEmpty && snapshots.saveCount == 0)
        #expect(viewModel.isInitialLoad && viewModel.listState == .loading, "spinning before the load as through it")

        let load = Task { await viewModel.loadIfStale() }
        await settle(until: { repository.requestedScopes.count == 1 })
        #expect(viewModel.listState == .loading && screenState(of: viewModel) == .loading)

        repository.releaseRequests()
        await load.value
        #expect(snapshots.load([SportEvent].self, for: key) == fresh && snapshots.saveCount == 1)
    }

    /// A join or a create made here is in the snapshot too, so a launch right after shows it.
    @Test func localChangesAreKeptAsTheSnapshot() async {
        repository.result = .success(fresh)
        let viewModel = makeViewModel()
        await viewModel.loadIfStale()

        let joined = SportEvent.fixture(id: "fresh", participants: 3, startsAt: fresh[0].startsAt, isJoined: true)
        viewModel.replace(joined)
        #expect(snapshots.load([SportEvent].self, for: key) == [joined])

        let created = SportEvent.fixture(id: "new", startsAt: Date(timeIntervalSince1970: 1_800_007_200))
        viewModel.add(created)
        #expect(snapshots.load([SportEvent].self, for: key) == [created, joined])
    }

    /// `isJoined` is one caller's answer: a guest never starts from a user's snapshot, and a guest's is the guest's.
    @Test func theSnapshotIsTheCallersOwn() async {
        snapshots.seed(held, for: key)
        identity.currentUserID = nil
        let guestList = makeViewModel()
        #expect(guestList.events.isEmpty)

        repository.result = .success(fresh)
        await guestList.loadIfStale()
        #expect(snapshots.load([SportEvent].self, for: ListSnapshotKey(list: "events-upcoming", userID: nil)) == fresh)
        #expect(snapshots.load([SportEvent].self, for: key) == held)

        identity.currentUserID = TestFixtures.user.id
        #expect(makeViewModel().events == held)
    }

    /// The list outlives the session: an answer for a caller who signed out meanwhile is neither shown nor kept as the
    /// next caller's snapshot (a guest's answer landing after a sign-in is still shown and reloaded, `EventListChangeTests`).
    @Test func anAnswerForACallerWhoSignedOutIsDropped() async {
        snapshots.seed(held, for: key)
        repository.result = .success(fresh)
        repository.holdsRequests = true
        let viewModel = makeViewModel()
        let load = Task { await viewModel.loadIfStale() }
        await settle(until: { repository.requestedScopes.count == 1 })

        identity.currentUserID = nil
        repository.releaseRequests()
        await load.value

        #expect(viewModel.events == held && !viewModel.hasLoaded && !viewModel.isLoading)
        #expect(snapshots.storedFiles == [key.fileName])
        #expect(logger.messages(in: .cache).filter { $0.contains("signed out; dropped") }.count == 1)
    }

    /// The session's end empties the list and forgets its loads; what the clearing writes is the snapshot store's to sweep.
    @Test func clearForgetsTheListAndItsLoads() async {
        repository.result = .success(fresh)
        let viewModel = makeViewModel()
        await viewModel.loadIfStale()

        viewModel.clear()

        #expect(viewModel.events.isEmpty && !viewModel.hasLoaded && viewModel.listState == .loading)
        await viewModel.loadIfStale()
        #expect(repository.requestedScopes.count == 2)
    }

    /// Home's games and Explore's list are snapshots of their own.
    @Test func eachScopeHasASnapshotOfItsOwn() {
        snapshots.seed(held, for: ListSnapshotKey(list: "events-joined", userID: TestFixtures.user.id))

        #expect(makeViewModel(scope: .joined).events == held)
        #expect(makeViewModel(scope: .upcoming).events.isEmpty)
        #expect(EventScope.group(id: "g1").snapshotList == "events-group-g1")
    }
}
