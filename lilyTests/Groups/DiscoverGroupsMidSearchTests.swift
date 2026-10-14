import Foundation
import Testing
@testable import lily

/// What lands while a Discover search is out (a group change anywhere, another caller) and a page that failed: the
/// answer is shown as it came, and the next appearance searches again when the page predates what landed.
@MainActor
struct DiscoverGroupsMidSearchTests {
    private let harness = GroupHarness()

    private func makeDiscover() -> DiscoverGroupsViewModel {
        harness.makeDiscoverGroupsViewModel()
    }

    /// A Discover search the repository holds at its first request, so what lands meanwhile can be scripted.
    private func heldSearch() async -> (viewModel: DiscoverGroupsViewModel, appearance: Task<Void, Never>) {
        harness.repository.result = .success([.fixture(id: "a")])
        harness.repository.holdsRequests = true
        let viewModel = makeDiscover()
        let appearance = Task { await viewModel.loadIfStale() }
        await settle(until: { harness.repository.requestedCursors.count == 1 })
        return (viewModel, appearance)
    }

    /// A join, leave or create anywhere while the page was out: the page is shown, and since it predates the change
    /// ("Joined" and the counts are the server's), the next appearance searches again.
    @Test func aChangeLandingMidSearchLeavesTheSearchStale() async {
        let (viewModel, appearance) = await heldSearch()

        harness.changes.recordChange()
        harness.repository.releaseRequests()
        await appearance.value
        #expect(viewModel.hasSearched && viewModel.groups.map(\.id) == ["a"], "the answer is still shown")

        await viewModel.loadIfStale()
        #expect(harness.repository.requestedCursors.count == 2, "the page predates the change")
    }

    /// A sign-in or sign-out while the page was out: the page is stamped with the caller it was fetched for, so the
    /// next appearance searches for the new one.
    @Test func aCallerChangeMidSearchLeavesTheSearchStale() async {
        let (viewModel, appearance) = await heldSearch()

        harness.identity.currentUserID = "someone-else"
        harness.repository.releaseRequests()
        await appearance.value
        #expect(viewModel.searchedUserID == TestFixtures.user.id, "the page is the previous caller's")

        await viewModel.loadIfStale()
        #expect(harness.repository.requestedCursors.count == 2, "the page predates the caller")
    }

    /// A page that failed reaches the popup and changes nothing on screen: the groups stay, and the cursor is kept so
    /// another try asks for the same page.
    @Test func aFailedPageReachesThePopupAndKeepsTheCursor() async {
        harness.repository.result = .success([.fixture(id: "a")])
        harness.repository.nextCursor = "c1"
        let viewModel = makeDiscover()
        await viewModel.loadIfStale()
        #expect(viewModel.canLoadMore)

        harness.repository.result = .failure(.network)
        await viewModel.loadMore()
        #expect(harness.presentedError == .network && viewModel.groups.map(\.id) == ["a"])
        #expect(viewModel.canLoadMore && viewModel.nextCursor == "c1" && harness.logs(.error).count == 1,
                "the cursor is kept for another try")

        harness.repository.result = .success([.fixture(id: "b")])
        harness.repository.nextCursor = nil
        await viewModel.loadMore()
        #expect(viewModel.groups.map(\.id) == ["a", "b"] && !viewModel.canLoadMore)
        #expect(harness.repository.requestedCursors == [nil, "c1", "c1"], "the same page was asked for again")
    }
}
