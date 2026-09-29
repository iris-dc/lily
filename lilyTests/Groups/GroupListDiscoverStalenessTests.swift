import Foundation
import Testing
@testable import lily

/// Discover behind the Explore carousel: when it searches again, and whether a failure reaches the popup.
@MainActor
struct GroupListDiscoverStalenessTests {
    private let harness = GroupHarness()

    private func makeDiscover() -> GroupListViewModel {
        GroupListViewModel(scope: .discover,
                           store: harness.store,
                           repository: harness.repository,
                           identity: harness.identity,
                           errorCenter: harness.errorCenter,
                           recorder: harness.recorder,
                           logger: harness.logger)
    }

    @Test func searchesOncePerAppearanceWhileNothingChanged() async {
        harness.repository.result = .success([.fixture(id: "a")])
        let viewModel = makeDiscover()

        await viewModel.loadIfStale()
        await viewModel.loadIfStale()

        #expect(harness.repository.requestedCursors.count == 1)
    }

    /// A join, leave or create anywhere moves the group-changes version; "Joined" and the counts are the server's.
    @Test func aGroupChangeElsewhereMakesTheNextAppearanceSearchAgain() async {
        harness.repository.result = .success([.fixture(id: "a")])
        let viewModel = makeDiscover()
        await viewModel.loadIfStale()

        harness.changes.recordChange()
        await viewModel.loadIfStale()

        #expect(harness.repository.requestedCursors.count == 2)
    }

    @Test func aQuietFailureIsLoggedButNeverShown() async {
        harness.repository.result = .failure(.groupsUnavailable)
        let viewModel = makeDiscover()
        viewModel.reportsSearchFailures = false

        await viewModel.loadIfStale()

        #expect(harness.presentedError == nil)
        #expect(harness.logs(.error).count == 1)
        #expect(viewModel.groups.isEmpty && !viewModel.isLoading)
    }
}
