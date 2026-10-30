import Foundation
import Testing
@testable import lily

/// The carousel's Discover starts from the first page the last run browsed for the caller and keeps a plain browse's page;
/// a search or a filter is the screen's own business and never a snapshot.
@MainActor
struct DiscoverGroupsSnapshotTests {
    private let harness = GroupHarness()
    private let snapshots = InMemoryListSnapshotStore()
    private let held = [SportGroup.fixture(id: "held")]
    private let fresh = [SportGroup.fixture(id: "fresh")]
    private let key = ListSnapshotKey(list: "groups-discover", userID: TestFixtures.user.id)

    private func makeViewModel() -> DiscoverGroupsViewModel {
        DiscoverGroupsViewModel(changes: harness.changes,
                                repository: harness.repository,
                                identity: harness.identity,
                                locationService: harness.location,
                                errorCenter: harness.errorCenter,
                                recorder: harness.recorder,
                                logger: harness.logger,
                                snapshots: snapshots)
    }

    /// Content on the first frame, the browse still made (nothing was searched), the page kept as the next snapshot.
    @Test func startsFromTheSnapshotAndKeepsThePlainBrowse() async {
        snapshots.seed(held, for: key)
        harness.repository.result = .success(fresh)
        let viewModel = makeViewModel()
        #expect(viewModel.groups == held && !viewModel.hasSearched && !viewModel.isInitialLoad)

        await viewModel.loadIfStale()

        #expect(harness.repository.requestedScopes.count == 1 && viewModel.groups == fresh)
        #expect(snapshots.load([SportGroup].self, for: key) == fresh && snapshots.saveCount == 1)
    }

    @Test func aFilteredBrowseIsNoSnapshot() async {
        harness.repository.result = .success(fresh)
        let viewModel = makeViewModel()
        await viewModel.loadIfStale()
        #expect(snapshots.saveCount == 1)

        viewModel.typeFilter = .tennis
        await settle(until: { harness.repository.requestedScopes.count == 2 && !viewModel.isLoading })

        #expect(snapshots.saveCount == 1)
    }

    /// The tab opening during the launch's warm-up joins the search out rather than spending a second request.
    @Test func loadIfStaleJoinsASearchInFlight() async {
        harness.repository.result = .success(fresh)
        harness.repository.holdsRequests = true
        let viewModel = makeViewModel()
        let first = Task { await viewModel.loadIfStale() }
        await settle(until: { harness.repository.requestedScopes.count == 1 })

        await viewModel.loadIfStale()
        harness.repository.releaseRequests()
        await first.value

        #expect(harness.repository.requestedScopes.count == 1 && viewModel.groups == fresh)
    }

    /// The view model outlives the session: its end (`clear`) forgets the page and the search, and a page still out
    /// then is dropped when it answers, so nothing of the caller is shown or kept for the next.
    @Test func theSessionEndingForgetsThePageAndDropsASearchOut() async {
        harness.repository.result = .success(fresh)
        harness.repository.holdsRequests = true
        let viewModel = makeViewModel()
        let search = Task { await viewModel.loadIfStale() }
        await settle(until: { harness.repository.requestedScopes.count == 1 })

        viewModel.clear()
        harness.identity.currentUserID = nil
        harness.repository.releaseRequests()
        await search.value

        #expect(viewModel.groups.isEmpty && !viewModel.hasSearched && !viewModel.isLoading && snapshots.storedFiles.isEmpty)
        await viewModel.loadIfStale()
        #expect(viewModel.groups == fresh && harness.repository.requestedScopes.count == 2)
    }

    /// "Joined" on a tile is one caller's answer: a guest's browse is kept apart from a user's.
    @Test func theSnapshotIsTheCallersOwn() async {
        snapshots.seed(held, for: key)
        harness.identity.currentUserID = nil
        let guestBrowse = makeViewModel()
        #expect(guestBrowse.groups.isEmpty)

        harness.repository.result = .success(fresh)
        await guestBrowse.loadIfStale()
        #expect(snapshots.load([SportGroup].self, for: ListSnapshotKey(list: "groups-discover", userID: nil)) == fresh)
        #expect(snapshots.load([SportGroup].self, for: key) == held)
    }
}
