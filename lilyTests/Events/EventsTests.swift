import Foundation
import Testing
@testable import lily

@MainActor
struct MockEventRepositoryTests {
    @Test func upcomingReturnsRequestedCount() async throws {
        let repository = MockEventRepository(now: .now, count: 5, logger: SpyLogger())
        #expect(try await repository.events(in: .upcoming).count == 5)
    }

    @Test func joinedIsNonEmptyStrictSubsetOfUpcoming() async throws {
        let repository = MockEventRepository(now: .now, count: 8, logger: SpyLogger())
        let upcoming = try await repository.events(in: .upcoming)
        let joined = try await repository.events(in: .joined)
        #expect(!joined.isEmpty)
        #expect(joined.count < upcoming.count)
        #expect(joined.allSatisfy(upcoming.contains))
    }

    @Test func fixturesNeverExceedCapacity() {
        for event in MockEventFixtures.make(now: .now, count: 40) {
            #expect(event.participantCount <= event.capacity)
            #expect(event.spotsLeft >= 0)
        }
    }

    @Test func fixturesAreInTheFutureAndChronological() {
        let now = Date()
        let events = MockEventFixtures.make(now: now, count: 5)
        #expect(events.allSatisfy { $0.startsAt > now })
        #expect(events.map(\.startsAt) == events.map(\.startsAt).sorted())
    }

    /// The map UI test taps a pin by its title, and templates repeat once the feed outgrows them.
    @Test func feedSizedFixturesHaveUniqueTitles() {
        let titles = MockEventFixtures.make(now: .now, count: AppConfig.Events.mockFeedSize).map(\.title)
        #expect(Set(titles).count == titles.count)
    }

    /// Keeps the map's selected-pin card exercising the "Full" copy, which once read "0 spots left".
    @Test func feedSizedFixturesIncludeAFullEvent() {
        let events = MockEventFixtures.make(now: .now, count: AppConfig.Events.mockFeedSize)
        #expect(events.contains { $0.isFull })
    }

    /// The feed should show every capacity state of the bar: an open, a nearly full (amber) and a full event.
    @Test func feedSizedFixturesCoverEveryCapacityState() {
        let events = MockEventFixtures.make(now: .now, count: AppConfig.Events.mockFeedSize)
        #expect(events.contains { $0.isNearlyFull })
        #expect(events.contains { !$0.isNearlyFull && !$0.isFull && $0.participantCount > 0 })
    }
}

@MainActor
struct EventListViewModelTests {
    private func makeViewModel(_ repository: FakeEventRepository,
                               location: Coordinate? = nil,
                               locationService: (any LocationService)? = nil,
                               now: @escaping () -> Date = { .now }) -> (EventListViewModel, ErrorCenter) {
        let center = ErrorCenter(logger: SpyLogger())
        let viewModel = EventListViewModel(scope: .upcoming,
                                           repository: repository,
                                           locationService: locationService ?? MockLocationService(coordinate: location),
                                           errorCenter: center,
                                           logger: SpyLogger(),
                                           now: now)
        return (viewModel, center)
    }

    /// Lets a held load run until it is observably suspended inside the repository.
    private func waitUntilLoading(_ viewModel: EventListViewModel) async {
        var attempts = 0
        while !viewModel.isLoading && attempts < 100 {
            await Task.yield()
            attempts += 1
        }
        #expect(viewModel.isLoading)
    }

    @Test func loadPopulatesEvents() async {
        let repository = FakeEventRepository()
        let events = MockEventFixtures.make(now: .now, count: 3)
        repository.result = .success(events)
        let (viewModel, _) = makeViewModel(repository)

        await viewModel.load()

        #expect(viewModel.events == events)
        #expect(!viewModel.isLoading)
        #expect(repository.requestedScopes == [.upcoming])
    }

    @Test func loadFailureReportsEventsUnavailable() async {
        let repository = FakeEventRepository()
        repository.result = .failure(.network)
        let (viewModel, center) = makeViewModel(repository)

        await viewModel.load()

        #expect(center.current?.error == .eventsUnavailable)
        #expect(viewModel.events.isEmpty)
        #expect(viewModel.loadFailed)
    }

    @Test func failedLoadIsFlaggedUntilTheNextSuccess() async {
        let repository = FakeEventRepository()
        repository.result = .failure(.network)
        let (viewModel, _) = makeViewModel(repository)
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
            let (viewModel, center) = makeViewModel(repository)

            await viewModel.load()

            #expect(center.current == nil)
            #expect(!viewModel.loadFailed)
            #expect(viewModel.events.isEmpty)
            #expect(!viewModel.isLoading)
        }
    }

    @Test func loadIfStaleReusesEventsUntilTheyExpire() async {
        let repository = FakeEventRepository()
        repository.result = .success(MockEventFixtures.make(now: .now, count: 2))
        var clock = Date(timeIntervalSince1970: 1_700_000_000)
        let (viewModel, _) = makeViewModel(repository, now: { clock })

        await viewModel.loadIfStale()
        await viewModel.loadIfStale()
        #expect(repository.requestedScopes.count == 1)

        clock = clock.addingTimeInterval(AppConfig.Events.listStaleAfter)
        await viewModel.loadIfStale()
        #expect(repository.requestedScopes.count == 2)
    }

    @Test func loadIfStaleRetriesAfterAFailure() async {
        let repository = FakeEventRepository()
        repository.result = .failure(.network)
        let (viewModel, _) = makeViewModel(repository)
        await viewModel.loadIfStale()

        repository.result = .success(MockEventFixtures.make(now: .now, count: 1))
        await viewModel.loadIfStale()

        #expect(repository.requestedScopes.count == 2)
        #expect(viewModel.events.count == 1)
    }

    @Test func loadAlwaysAsksTheRepository() async {
        let repository = FakeEventRepository()
        let (viewModel, _) = makeViewModel(repository)

        await viewModel.load()
        await viewModel.load()

        #expect(repository.requestedScopes.count == 2)
    }

    @Test func loadIgnoresReentrantCallWhileLoading() async {
        let repository = FakeEventRepository()
        repository.holdsRequests = true
        let (viewModel, _) = makeViewModel(repository)

        let first = Task { await viewModel.load() }
        await waitUntilLoading(viewModel)
        let second = Task { await viewModel.load() }
        for _ in 0..<10 { await Task.yield() }
        #expect(repository.requestedScopes == [.upcoming])

        repository.releaseRequests()
        await first.value
        await second.value
        #expect(!viewModel.isLoading)
    }

    @Test func initialLoadEndsWithTheFirstResult() async {
        let repository = FakeEventRepository()
        repository.result = .failure(.network)
        repository.holdsRequests = true
        let (viewModel, _) = makeViewModel(repository)

        let first = Task { await viewModel.load() }
        await waitUntilLoading(viewModel)
        #expect(viewModel.isInitialLoad)
        repository.releaseRequests()
        await first.value
        #expect(!viewModel.isInitialLoad)

        repository.holdsRequests = true
        let retry = Task { await viewModel.load() }
        await waitUntilLoading(viewModel)
        #expect(!viewModel.isInitialLoad)
        repository.releaseRequests()
        await retry.value
    }

    @Test func loadUserLocationQueriesServiceOnce() async {
        let service = FakeLocationService()
        service.result = AppConfig.Location.mockCenter
        let (viewModel, _) = makeViewModel(FakeEventRepository(), locationService: service)

        await viewModel.loadUserLocation()
        await viewModel.loadUserLocation()

        #expect(service.callCount == 1)
        #expect(viewModel.userLocation == AppConfig.Location.mockCenter)
    }

    @Test func userLocationEnablesDistanceText() async {
        let repository = FakeEventRepository()
        let events = MockEventFixtures.make(now: .now, count: 1)
        repository.result = .success(events)
        let (viewModel, _) = makeViewModel(repository, location: AppConfig.Location.mockCenter)
        await viewModel.load()

        #expect(viewModel.distanceText(for: events[0]) == nil)
        await viewModel.loadUserLocation()
        #expect(viewModel.userLocation == AppConfig.Location.mockCenter)
        #expect(viewModel.distanceText(for: events[0])?.isEmpty == false)
    }

    @Test func missingLocationLeavesDistanceEmpty() async {
        let (viewModel, _) = makeViewModel(FakeEventRepository(), location: nil)
        await viewModel.loadUserLocation()
        #expect(viewModel.userLocation == nil)
        #expect(viewModel.distanceText(for: MockEventFixtures.make(now: .now, count: 1)[0]) == nil)
    }

    @Test func retryAsksAgainOnlyWhileThePositionIsMissing() async {
        let service = FakeLocationService()
        service.result = nil
        let (viewModel, _) = makeViewModel(FakeEventRepository(), locationService: service)
        await viewModel.loadUserLocation()
        #expect(viewModel.userLocation == nil && service.callCount == 1)

        service.result = AppConfig.Location.mockCenter
        await viewModel.retryUserLocationIfMissing()
        #expect(viewModel.userLocation == AppConfig.Location.mockCenter && service.callCount == 2)

        await viewModel.retryUserLocationIfMissing()
        #expect(service.callCount == 2)
    }
}
