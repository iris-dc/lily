import Foundation
import Testing
@testable import lily

@MainActor
struct TournamentListViewModelTests {
    private let harness = TournamentHarness()

    @Test func upcomingSendsThePositionAndTheOthersDoNot() async {
        harness.repository.result = .success([.fixture()])
        let location = MockLocationService(coordinate: AppConfig.Location.mockCenter)
        let explore = harness.makeListViewModel(scope: .upcoming, locationService: location)
        let mine = harness.makeListViewModel(scope: .mine)

        await explore.loadUserLocation()
        await explore.load()
        await mine.load()

        #expect(harness.repository.requestedScopes == [.upcoming, .mine])
        #expect(harness.repository.requestedPositions[0] == AppConfig.Location.mockCenter)
        #expect(harness.repository.requestedPositions[1] == nil)
        #expect(explore.tournaments.count == 1 && explore.hasLoaded && !explore.isLoading)
        #expect(explore.distanceText(for: .fixture()) != nil && mine.distanceText(for: .fixture()) == nil)
    }

    /// Explore content loaded before the position was known is loaded again once it is (the backend ranks by distance),
    /// once per coarse position and once more when the user moves; Home's list never minds the position.
    @Test func upcomingReloadsOnceWhenThePositionArrivesOrMoves() async {
        harness.repository.result = .success([.fixture()])
        let location = FakeLocationService()
        let explore = harness.makeListViewModel(scope: .upcoming, locationService: location)
        let mine = harness.makeListViewModel(scope: .mine, locationService: location)

        await explore.loadIfStale()
        await mine.loadIfStale()
        #expect(harness.repository.requestedPositions == [nil, nil])

        location.result = Coordinate(latitude: 52.5231, longitude: 13.4049)
        await explore.loadUserLocation()
        await mine.loadUserLocation()
        #expect(harness.repository.requestedScopes == [.upcoming, .mine, .upcoming])
        #expect(harness.repository.requestedPositions.last == location.result)
        #expect(harness.logger.messages(in: .cache).contains { $0.contains("position became known") })

        await explore.loadUserLocation()
        await explore.loadIfStale()
        #expect(harness.repository.requestedScopes.count == 3, "the same coarse position is no reason to reload")

        location.result = Coordinate(latitude: 52.60, longitude: 13.40)
        await explore.loadUserLocation()
        #expect(harness.repository.requestedScopes.count == 4)
        #expect(harness.logger.messages(in: .cache).contains { $0.contains("position changed") })
    }

    @Test func loadIfStaleReusesTheListUntilAChangeOrTheTTL() async {
        harness.repository.result = .success([.fixture()])
        let viewModel = harness.makeListViewModel(scope: .upcoming)

        await viewModel.loadIfStale()
        await viewModel.loadIfStale()
        #expect(harness.repository.requestedScopes.count == 1)
        #expect(harness.logger.messages(in: .cache).contains { $0.contains("never loaded") })

        harness.changes.recordChange()
        await viewModel.loadIfStale()
        #expect(harness.repository.requestedScopes.count == 2)
        #expect(harness.logger.messages(in: .cache).contains { $0.contains("changed elsewhere") })
    }

    /// A guest has no tournaments of their own: Mine is cleared without a request, Explore still loads.
    @Test func mineAsksNothingForAGuest() async {
        harness.identity.currentUserID = nil
        harness.repository.result = .success([.fixture()])
        let mine = harness.makeListViewModel(scope: .mine)
        let explore = harness.makeListViewModel(scope: .upcoming)

        await mine.loadIfStale()
        await explore.loadIfStale()

        #expect(harness.repository.requestedScopes == [.upcoming] && mine.tournaments.isEmpty)
    }

    @Test func aFailedLoadReachesThePopupUnlessTheListKeepsItToItself() async {
        harness.repository.result = .failure(.tournamentsUnavailable)
        let reporting = harness.makeListViewModel(scope: .upcoming)
        await reporting.load()
        #expect(reporting.loadFailed && harness.presentedError == .tournamentsUnavailable)
        #expect(harness.logs(.error).contains { $0.contains("Loading tournaments failed") })

        let quietHarness = TournamentHarness()
        quietHarness.repository.result = .failure(.tournamentsUnavailable)
        let quiet = quietHarness.makeListViewModel(scope: .upcoming)
        quiet.reportsFailures = false
        await quiet.load()
        #expect(quiet.loadFailed && quietHarness.presentedError == nil)
    }

    @Test func theTypeFilterNarrowsDiscoverOnDevice() async {
        harness.repository.result = .success([.fixture(id: "a", type: .tableTennis), .fixture(id: "b", type: .football)])
        let viewModel = harness.makeListViewModel(scope: .upcoming)
        await viewModel.load()

        viewModel.typeFilter = .football
        #expect(viewModel.visibleTournaments.map(\.id) == ["b"])
        viewModel.typeFilter = nil
        #expect(viewModel.visibleTournaments.count == 2)
    }

    /// A change on the detail replaces the row, or drops it when the tournament left the scope; sibling lists are told.
    @Test func replaceUpdatesOrDropsAndInvalidatesSiblings() async {
        harness.repository.result = .success([.fixture(id: "a", entryCount: 2), .fixture(id: "b")])
        let explore = harness.makeListViewModel(scope: .upcoming)
        await explore.load()
        let version = harness.changes.version

        explore.replace(.fixture(id: "a", entryCount: 3))
        #expect(explore.tournaments.first { $0.id == "a" }?.entryCount == 3)
        explore.replace(.fixture(id: "b", status: .cancelled))
        #expect(explore.tournaments.map(\.id) == ["a"], "a cancelled tournament is off Explore")
        #expect(harness.changes.version == version + 2)

        await explore.loadIfStale()
        #expect(harness.repository.requestedScopes.count == 1, "this list already shows the change and does not reload")
    }

    @Test func addPlacesACreatedTournamentByStartWhereItBelongs() async {
        let early = Tournament.fixture(id: "early", startsAt: Date(timeIntervalSince1970: 1_800_000_000))
        let late = Tournament.fixture(id: "late", startsAt: Date(timeIntervalSince1970: 1_800_100_000))
        harness.repository.result = .success([early, late])
        let explore = harness.makeListViewModel(scope: .upcoming)
        let mine = harness.makeListViewModel(scope: .mine)
        let group = harness.makeListViewModel(scope: .group(id: "g"))
        await explore.load()
        await mine.load()
        await group.load()

        let middle = Tournament.fixture(id: "middle",
                                        startsAt: Date(timeIntervalSince1970: 1_800_050_000),
                                        organizerUserId: TestFixtures.user.id)
        explore.add(middle)
        mine.add(middle)
        group.add(middle)
        explore.add(middle)

        #expect(explore.tournaments.map(\.id) == ["early", "middle", "late"])
        #expect(mine.tournaments.map(\.id) == ["early", "middle", "late"], "the caller organises it")
        #expect(group.tournaments.map(\.id) == ["early", "late"], "not this group's")
        let privateOne = Tournament.fixture(id: "private", visibility: .private)
        explore.add(privateOne)
        #expect(!explore.tournaments.contains(where: { $0.id == "private" }), "Explore never lists a private tournament")
    }
}
