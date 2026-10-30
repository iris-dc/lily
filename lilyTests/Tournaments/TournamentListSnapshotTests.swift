import Foundation
import Testing
@testable import lily

/// The tournament lists of the tabs start from the snapshot the last run left for the caller and keep every answer.
@MainActor
struct TournamentListSnapshotTests {
    private let harness = TournamentHarness()
    private let snapshots = InMemoryListSnapshotStore()
    private let held = [Tournament.fixture(id: "held")]
    private let fresh = [Tournament.fixture(id: "fresh")]
    private let key = ListSnapshotKey(list: "tournaments-upcoming", userID: TestFixtures.user.id)

    private func makeViewModel(scope: TournamentScope = .upcoming) -> TournamentListViewModel {
        TournamentListViewModel(scope: scope,
                                repository: harness.repository,
                                identity: harness.identity,
                                locationService: MockLocationService(),
                                changes: harness.changes,
                                errorCenter: harness.errorCenter,
                                logger: harness.logger,
                                now: { TournamentHarness.now },
                                snapshots: snapshots)
    }

    /// Content on the first frame, the load still made, the answer kept as the next snapshot.
    @Test func startsFromTheSnapshotAndKeepsTheAnswer() async {
        snapshots.seed(held, for: key)
        harness.repository.result = .success(fresh)
        let viewModel = makeViewModel()
        #expect(viewModel.tournaments == held && !viewModel.hasLoaded && viewModel.listState == .content)
        #expect(snapshots.saveCount == 0)

        await viewModel.loadIfStale()

        #expect(harness.repository.requestedScopes == [.upcoming])
        #expect(viewModel.tournaments == fresh && snapshots.load([Tournament].self, for: key) == fresh)
    }

    /// The list outlives the session: an answer for a caller who signed out meanwhile is dropped, and `clear` forgets
    /// the list and its loads.
    @Test func anAnswerForAPreviousCallerIsDroppedAndClearForgets() async {
        harness.repository.result = .success(fresh)
        harness.repository.holdsRequests = true
        let viewModel = makeViewModel()
        let load = Task { await viewModel.loadIfStale() }
        await settle(until: { harness.repository.requestedScopes.count == 1 })

        harness.identity.currentUserID = nil
        harness.repository.releaseRequests()
        await load.value
        #expect(viewModel.tournaments.isEmpty && !viewModel.hasLoaded && snapshots.storedFiles.isEmpty)

        harness.identity.currentUserID = TestFixtures.user.id
        await viewModel.loadIfStale()
        #expect(viewModel.tournaments == fresh)
        viewModel.clear()
        #expect(viewModel.tournaments.isEmpty && !viewModel.hasLoaded)
    }

    /// Home's tournaments are the caller's: kept under them, never read for another.
    @Test func mineIsKeptPerCaller() async {
        harness.repository.result = .success(fresh)
        let mine = makeViewModel(scope: .mine)
        await mine.loadIfStale()
        let mineKey = ListSnapshotKey(list: "tournaments-mine", userID: TestFixtures.user.id)
        #expect(snapshots.load([Tournament].self, for: mineKey) == fresh)

        harness.identity.currentUserID = "someone-else"
        #expect(makeViewModel(scope: .mine).tournaments.isEmpty)
        #expect(TournamentScope.group(id: "g1").snapshotList == "tournaments-group-g1")
    }
}
