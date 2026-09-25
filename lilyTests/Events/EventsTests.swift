import Foundation
import Testing
@testable import lily

@MainActor
struct MockEventRepositoryTests {
    @Test func upcomingReturnsRequestedCount() async throws {
        let repository = MockEventRepository(now: .now, count: 5, identity: FakeIdentityProvider(), logger: SpyLogger())
        #expect(try await repository.events(in: .upcoming, near: nil).count == 5)
    }

    @Test func joinedIsNonEmptyStrictSubsetOfUpcoming() async throws {
        let repository = MockEventRepository(now: .now, count: 8, identity: FakeIdentityProvider(), logger: SpyLogger())
        let upcoming = try await repository.events(in: .upcoming, near: nil)
        let joined = try await repository.events(in: .joined, near: nil)
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

    /// Two fixtures are hosted in groups (one public, one private), so the badge and "Hosted in" have data; the group
    /// scope lists exactly the games of that group.
    @Test func twoFixturesCarryGroupRefsAndTheGroupScopeFiltersByThem() async throws {
        let repository = MockEventRepository(now: .now,
                                             count: AppConfig.Events.mockFeedSize,
                                             identity: FakeIdentityProvider(),
                                             logger: SpyLogger())
        let all = try await repository.events(in: .upcoming, near: nil)

        let grouped = all.filter { $0.group != nil }
        #expect(grouped.map(\.group?.id) == [MockGroupFixtures.kickersID, MockGroupFixtures.padelID])
        #expect(grouped.map(\.group?.visibility) == [.public, .private])
        #expect(grouped.allSatisfy { $0.group?.isDeleted == false })
        #expect(try await repository.events(in: .group(id: MockGroupFixtures.kickersID), near: nil) == [grouped[0]])
        #expect(try await repository.events(in: .group(id: "nowhere"), near: nil).isEmpty)
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

    @Test func loadUserLocationQueriesServiceOnce() async {
        let service = FakeLocationService()
        service.result = AppConfig.Location.mockCenter
        let viewModel = makeEventListViewModel(repository: FakeEventRepository(), locationService: service)

        await viewModel.loadUserLocation()
        await viewModel.loadUserLocation()

        #expect(service.callCount == 1)
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

    @Test func retryAsksAgainOnlyWhileThePositionIsMissing() async {
        let service = FakeLocationService()
        service.result = nil
        let viewModel = makeEventListViewModel(repository: FakeEventRepository(), locationService: service)
        await viewModel.loadUserLocation()
        #expect(viewModel.userLocation == nil && service.callCount == 1)

        service.result = AppConfig.Location.mockCenter
        await viewModel.retryUserLocationIfMissing()
        #expect(viewModel.userLocation == AppConfig.Location.mockCenter && service.callCount == 2)

        await viewModel.retryUserLocationIfMissing()
        #expect(service.callCount == 2)
    }
}
