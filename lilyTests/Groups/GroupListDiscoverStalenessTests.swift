import Foundation
import Testing
@testable import lily

/// Discover behind the Explore carousel: when it searches again (a change, the caller, the user's position), and
/// whether a failure reaches the popup.
@MainActor
struct GroupListDiscoverStalenessTests {
    private let harness = GroupHarness()
    private static let berlin = Coordinate(latitude: 52.5231, longitude: 13.4049)
    /// `berlin` as the backend receives it and the view model compares it.
    private static let coarseBerlin = Coordinate(latitude: 52.52, longitude: 13.4)

    private func makeDiscover() -> GroupListViewModel {
        makeViewModel(scope: .discover)
    }

    private func makeViewModel(scope: GroupListScope) -> GroupListViewModel {
        GroupListViewModel(scope: scope,
                           store: harness.store,
                           repository: harness.repository,
                           identity: harness.identity,
                           locationService: harness.location,
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

    /// A browse sends the user's position (coarse, as the backend receives it) so the page is the groups around them;
    /// one searched without it, or for another position, is searched again once the position is known, and the same
    /// coarse position never twice.
    @Test func aBrowseSendsThePositionAndSearchesAgainWhenItArrives() async {
        harness.repository.result = .success([.fixture(id: "a")])
        let viewModel = makeDiscover()

        await viewModel.loadIfStale()
        #expect(harness.repository.requestedPositions == [nil])

        harness.location.result = Self.berlin
        await viewModel.loadUserLocation()
        #expect(viewModel.userLocation == Self.berlin)
        #expect(harness.repository.requestedPositions == [nil, Self.coarseBerlin])

        await viewModel.loadUserLocation()
        await viewModel.loadIfStale()
        #expect(harness.repository.requestedPositions.count == 2, "the same coarse position is no reason to search again")

        harness.location.result = Coordinate(latitude: 52.60, longitude: 13.40)
        await viewModel.loadUserLocation()
        #expect(harness.repository.requestedPositions.count == 3, "a move is a reason")
        #expect(harness.logger.messages(in: .cache, at: .debug).contains { $0.contains("another position") })
    }

    /// A position that arrives while the first search is out does not start a second one over it: the search in
    /// flight notices the position when it answers and asks once more with it, and that page is then fresh.
    @Test func aPositionArrivingMidSearchEarnsOneSearchWithIt() async {
        harness.repository.result = .success([.fixture(id: "a")])
        harness.repository.holdsRequests = true
        let viewModel = makeDiscover()

        let appearance = Task { await viewModel.loadIfStale() }
        await settle(until: { harness.repository.requestedPositions.count == 1 })
        harness.location.result = Self.berlin
        await viewModel.loadUserLocation()
        #expect(harness.repository.requestedPositions.count == 1 && viewModel.isLoading, "the search in flight will notice")

        harness.repository.releaseRequests()
        await appearance.value
        #expect(harness.repository.requestedPositions == [nil, Self.coarseBerlin])
        #expect(viewModel.hasSearched && !viewModel.isLoading)
        #expect(harness.logger.messages(in: .cache, at: .debug).contains { $0.contains("while Discover searched") })

        await viewModel.loadUserLocation()
        await viewModel.loadIfStale()
        #expect(harness.repository.requestedPositions.count == 2, "the page is the one around the user")
    }

    /// A search cancelled on the way out (the tab was left) takes nothing: the page on screen and the position it was
    /// searched for stay as they were, nothing is reported, and the next appearance searches for the position.
    @Test func aCancelledSearchLeavesTheNextAppearanceToSearchForThePosition() async {
        harness.repository.result = .success([.fixture(id: "a")])
        let viewModel = makeDiscover()
        await viewModel.loadIfStale()
        harness.location.result = Self.berlin
        harness.repository.holdsRequests = true

        let appearance = Task { await viewModel.loadUserLocation() }
        await settle(until: { harness.repository.requestedPositions.count == 2 })
        appearance.cancel()
        harness.repository.releaseRequests()
        await appearance.value
        #expect(viewModel.groups.map(\.id) == ["a"] && !viewModel.isLoading)
        #expect(harness.presentedError == nil && harness.logs(.error).isEmpty)

        await viewModel.loadIfStale()
        #expect(harness.repository.requestedPositions == [nil, Self.coarseBerlin, Self.coarseBerlin])
    }

    /// A failed search for the position is not repeated at once (a backend that is down is not asked in a loop); the
    /// page on screen stays, and the next appearance tries again.
    @Test func aFailedSearchForThePositionWaitsForTheNextAppearance() async {
        harness.repository.result = .success([.fixture(id: "a")])
        let viewModel = makeDiscover()
        viewModel.reportsSearchFailures = false
        await viewModel.loadIfStale()
        harness.location.result = Self.berlin
        harness.repository.result = .failure(.groupsUnavailable)

        await viewModel.loadUserLocation()
        #expect(harness.repository.requestedPositions.count == 2 && harness.logs(.error).count == 1)
        #expect(viewModel.groups.map(\.id) == ["a"] && !viewModel.isLoading, "the page on screen stays")

        harness.repository.result = .success([.fixture(id: "b")])
        await viewModel.loadIfStale()
        #expect(harness.repository.requestedPositions.count == 3 && viewModel.groups.map(\.id) == ["b"])
    }

    /// Mine takes the position for nothing but distances: it never searches, whatever the position does.
    @Test func mineTakesThePositionAndNeverSearches() async {
        harness.repository.result = .success([.fixture(id: "a", role: .member)])
        harness.location.result = Self.berlin
        let mine = makeViewModel(scope: .mine)

        await mine.loadIfStale()
        await mine.loadUserLocation()
        harness.location.result = Coordinate(latitude: 52.60, longitude: 13.40)
        await mine.loadUserLocation()

        #expect(mine.userLocation == harness.location.result)
        #expect(harness.repository.requestedScopes == [.mine] && harness.repository.requestedPositions == [nil])
    }

    /// A position known before the first search rides with it; a name search is global and sends none.
    @Test func aNameSearchSendsNoPositionAndDistancesFollowTheUser() async {
        let beach = EventLocation(name: "Beach Mitte", coordinate: AppConfig.Location.mockCenter)
        harness.repository.result = .success([.fixture(id: "a", location: beach)])
        harness.location.result = Coordinate(latitude: 52.53, longitude: 13.405)
        let viewModel = makeDiscover()

        await viewModel.loadUserLocation()
        #expect(harness.repository.requestedPositions.isEmpty, "nothing searched yet, nothing to search again")
        await viewModel.loadIfStale()
        #expect(harness.repository.requestedPositions == [Coordinate(latitude: 52.53, longitude: 13.41)])
        #expect(viewModel.distanceText(for: viewModel.groups[0]) != nil)
        #expect(viewModel.distanceText(for: .fixture(id: "b")) == nil, "no place, no distance")

        viewModel.query = "beach"
        await viewModel.search()
        #expect(harness.repository.requestedPositions.last == .some(nil))
        #expect(harness.repository.requestedScopes.last == .discover(query: "beach", type: nil))
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
