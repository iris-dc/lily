import Foundation
import Testing
@testable import lily

@MainActor
struct EventListViewModelTests {
    @Test func loadPopulatesEvents() async {
        let repository = FakeEventRepository()
        let events = MockEventFixtures.make(now: .now, count: 3)
        repository.result = .success(events)
        let viewModel = makeEventListViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.events == events)
        #expect(!viewModel.isLoading)
        #expect(repository.requestedScopes == [.upcoming])
    }

    /// The popup says what went wrong ("You're offline" here), not a blanket "Events unavailable".
    @Test func loadFailureReportsTheMappedError() async {
        let repository = FakeEventRepository()
        repository.result = .failure(.network)
        let center = ErrorCenter(logger: SpyLogger())
        let viewModel = makeEventListViewModel(repository: repository, errorCenter: center)

        await viewModel.load()

        #expect(center.current?.error == .network)
        #expect(viewModel.events.isEmpty)
        #expect(viewModel.loadFailed)
    }

    @Test func failedLoadIsFlaggedUntilTheNextSuccess() async {
        let repository = FakeEventRepository()
        repository.result = .failure(.network)
        let viewModel = makeEventListViewModel(repository: repository)
        await viewModel.load()
        #expect(viewModel.loadFailed)

        let events = MockEventFixtures.make(now: .now, count: 2)
        repository.result = .success(events)
        await viewModel.load()

        #expect(!viewModel.loadFailed)
        #expect(viewModel.events == events)
    }

    @Test func cancelledLoadIsNotReportedAsFailure() async {
        for cancellation: any Error in [CancellationError(), URLError(.cancelled)] {
            let repository = FakeEventRepository()
            repository.thrownError = cancellation
            let center = ErrorCenter(logger: SpyLogger())
            let viewModel = makeEventListViewModel(repository: repository, errorCenter: center)

            await viewModel.load()

            #expect(center.current == nil)
            #expect(!viewModel.loadFailed)
            #expect(viewModel.events.isEmpty)
            #expect(!viewModel.isLoading)
        }
    }

    @Test func loadAfterAFailureIsNotHeldBack() async {
        let repository = FakeEventRepository()
        repository.result = .failure(.network)
        let viewModel = makeEventListViewModel(repository: repository)
        await viewModel.loadIfStale()

        await viewModel.load()

        #expect(repository.requestedScopes.count == 2)
    }

    @Test func loadAlwaysAsksTheRepository() async {
        let repository = FakeEventRepository()
        let viewModel = makeEventListViewModel(repository: repository)

        await viewModel.load()
        await viewModel.load()

        #expect(repository.requestedScopes.count == 2)
    }

    /// A dropped re-entrant load returns at once, so awaiting it directly is the observation.
    @Test func loadIgnoresReentrantCallWhileLoading() async {
        let repository = FakeEventRepository()
        repository.holdsRequests = true
        let viewModel = makeEventListViewModel(repository: repository)

        let first = Task { await viewModel.load() }
        await settle(until: { viewModel.isLoading })
        await viewModel.load()
        #expect(repository.requestedScopes == [.upcoming])

        repository.releaseRequests()
        await first.value
        #expect(!viewModel.isLoading)
    }

    @Test func initialLoadEndsWithTheFirstResult() async {
        let repository = FakeEventRepository()
        repository.result = .failure(.network)
        repository.holdsRequests = true
        let viewModel = makeEventListViewModel(repository: repository)

        let first = Task { await viewModel.load() }
        await settle(until: { viewModel.isLoading })
        #expect(viewModel.isInitialLoad)
        repository.releaseRequests()
        await first.value
        #expect(!viewModel.isInitialLoad)

        repository.holdsRequests = true
        let retry = Task { await viewModel.load() }
        await settle(until: { viewModel.isLoading })
        #expect(!viewModel.isInitialLoad)
        repository.releaseRequests()
        await retry.value
    }

    /// Reusing a recent fix is `CachedLocationService`'s job; the view model asks on every appearance, so a tab that
    /// reappears after the cache's TTL follows the user.
    @Test func loadUserLocationAsksTheServiceEveryTime() async {
        let service = FakeLocationService()
        service.result = AppConfig.Location.mockCenter
        let viewModel = makeEventListViewModel(repository: FakeEventRepository(), locationService: service)

        await viewModel.loadUserLocation()
        await viewModel.loadUserLocation()

        #expect(service.callCount == 2)
        #expect(viewModel.userLocation == AppConfig.Location.mockCenter)
    }

    @Test func userLocationEnablesDistanceText() async {
        let repository = FakeEventRepository()
        let events = MockEventFixtures.make(now: .now, count: 1)
        repository.result = .success(events)
        let viewModel = makeEventListViewModel(repository: repository,
                                               locationService: MockLocationService(coordinate: AppConfig.Location.mockCenter))
        await viewModel.load()

        #expect(viewModel.distanceText(for: events[0]) == nil)
        await viewModel.loadUserLocation()
        #expect(viewModel.userLocation == AppConfig.Location.mockCenter)
        #expect(viewModel.distanceText(for: events[0])?.isEmpty == false)
    }

    @Test func missingLocationLeavesDistanceEmpty() async {
        let viewModel = makeEventListViewModel(repository: FakeEventRepository(),
                                               locationService: MockLocationService(coordinate: nil))
        await viewModel.loadUserLocation()
        #expect(viewModel.userLocation == nil)
        #expect(viewModel.distanceText(for: MockEventFixtures.make(now: .now, count: 1)[0]) == nil)
    }

    /// The return to the foreground asks again whether a position is known or not: permission may have changed, and
    /// so may the user's whereabouts.
    @Test func refreshFollowsTheUserEvenWhenAPositionIsKnown() async {
        let service = FakeLocationService()
        service.result = nil
        let viewModel = makeEventListViewModel(repository: FakeEventRepository(), locationService: service)
        await viewModel.loadUserLocation()
        #expect(viewModel.userLocation == nil && service.callCount == 1)

        service.result = AppConfig.Location.mockCenter
        await viewModel.refreshUserLocation()
        #expect(viewModel.userLocation == AppConfig.Location.mockCenter && service.callCount == 2)

        service.result = TestFixtures.elsewhere
        await viewModel.refreshUserLocation()
        #expect(viewModel.userLocation == TestFixtures.elsewhere && service.callCount == 3)
    }

    /// A fix that times out on a later ask must not blank the distances the user was just reading.
    @Test func aMissedFixKeepsTheLastKnownPosition() async {
        let service = FakeLocationService()
        service.result = AppConfig.Location.mockCenter
        let viewModel = makeEventListViewModel(repository: FakeEventRepository(), locationService: service)
        await viewModel.loadUserLocation()

        service.result = nil
        await viewModel.refreshUserLocation()

        #expect(service.callCount == 2)
        #expect(viewModel.userLocation == AppConfig.Location.mockCenter)
    }

    /// The position is asked for on every appearance, so only a change is worth an info line; the rest is debug.
    @Test func locationIsLoggedAtInfoOnlyWhenItChanges() async {
        let service = FakeLocationService()
        let logger = SpyLogger()
        let viewModel = makeEventListViewModel(repository: FakeEventRepository(), locationService: service, logger: logger)

        service.result = nil
        await viewModel.loadUserLocation()
        service.result = AppConfig.Location.mockCenter
        await viewModel.loadUserLocation()
        await viewModel.loadUserLocation()
        service.result = TestFixtures.elsewhere
        await viewModel.loadUserLocation()

        #expect(logger.count(in: .location, at: .info) == 2, "one info line when the position became known, one when it moved")
        #expect(logger.count(in: .location, at: .info, mentioning: "available") == 1)
        #expect(logger.count(in: .location, at: .info, mentioning: "changed") == 1)
        #expect(logger.count(in: .location, at: .debug) == 2, "a miss and an unchanged fix are debug")
        #expect(logger.count(in: .location, at: .debug, mentioning: "No user location") == 1)
        #expect(logger.count(in: .location, at: .debug, mentioning: "unchanged") == 1)
    }
}
