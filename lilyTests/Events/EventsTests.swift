import Foundation
import Testing
@testable import lily

@MainActor
struct MockEventRepositoryTests {
    /// `count` sizes the fixture set; Explore lists all of them but the private group's game (index 3), like the backend.
    @Test func upcomingListsTheRequestedFixturesButThePrivateGroups() async throws {
        let repository = MockEventRepository(now: .now, count: 5, identity: FakeIdentityProvider(), logger: SpyLogger())
        let upcoming = try await repository.events(in: .upcoming, near: nil)
        #expect(upcoming.count == 4)
        #expect(upcoming.allSatisfy { $0.isListed })
    }

    @Test func joinedIsNonEmptyStrictSubsetOfUpcoming() async throws {
        let repository = MockEventRepository(now: .now, count: 8, identity: FakeIdentityProvider(), logger: SpyLogger())
        let upcoming = try await repository.events(in: .upcoming, near: nil)
        let joined = try await repository.events(in: .joined, near: nil)
        #expect(!joined.isEmpty)
        #expect(joined.count < upcoming.count)
        #expect(joined.allSatisfy(upcoming.contains))
    }

    /// A cap is never exceeded; a game that allows extras may stand past the number it needs.
    @Test func fixturesNeverExceedACap() throws {
        for event in MockEventFixtures.make(now: .now, count: 40) where event.playerLimit == .maximum {
            let capacity = try #require(event.capacity)
            #expect(event.participantCount <= capacity)
            #expect(event.spotsLeft >= 0)
        }
    }

    /// Explore shows a game short of the players it needs, one past them and one without any limit; none can be full.
    @Test func feedSizedFixturesShowEveryKindOfOpenGame() {
        let listed = MockEventFixtures.make(now: .now, count: AppConfig.Events.mockFeedSize).filter(\.isListed)
        let needing = listed.filter { $0.playerLimit == .minimum }
        #expect(needing.contains { !$0.hasPlayersNeeded })
        #expect(needing.contains { $0.hasPlayersNeeded && $0.spotsLeft == 0 })
        #expect(listed.contains { $0.playerLimit == .unlimited && $0.participantCount > 0 })
        #expect(listed.filter { $0.playerLimit != .maximum }.allSatisfy { !$0.isFull })
    }

    @Test func fixturesAreInTheFutureAndChronological() {
        let now = Date()
        let events = MockEventFixtures.make(now: now, count: 5)
        #expect(events.allSatisfy { $0.startsAt > now })
        #expect(events.map(\.startsAt) == events.map(\.startsAt).sorted())
    }

    /// Two fixtures are hosted in groups (one public, one private), so the badge and "Hosted in" have data. Like the
    /// backend, Explore lists the public group's game only; the private group's is found under its group's scope.
    @Test func groupedFixturesFollowTheirGroupsVisibility() async throws {
        let repository = MockEventRepository(now: .now,
                                             count: AppConfig.Events.mockFeedSize,
                                             identity: FakeIdentityProvider(),
                                             logger: SpyLogger())
        let upcoming = try await repository.events(in: .upcoming, near: nil)
        let kickers = try await repository.events(in: .group(id: MockGroupFixtures.kickersID), near: nil)
        let padel = try await repository.events(in: .group(id: MockGroupFixtures.padelID), near: nil)

        #expect(upcoming.filter { $0.group != nil } == kickers)
        #expect(kickers.map(\.group?.visibility) == [.public])
        #expect(padel.map(\.group?.visibility) == [.private])
        #expect(!upcoming.contains { $0.group?.isPrivate == true })
        #expect((kickers + padel).allSatisfy { $0.group?.isDeleted == false })
        #expect(try await repository.events(in: .group(id: "nowhere"), near: nil).isEmpty)
    }

    /// The map UI test taps a pin by its title, and templates repeat once the feed outgrows them.
    @Test func feedSizedFixturesHaveUniqueTitles() {
        let titles = MockEventFixtures.make(now: .now, count: AppConfig.Events.mockFeedSize).map(\.title)
        #expect(Set(titles).count == titles.count)
    }

    /// Keeps the map's selected-pin card exercising the "Full" copy, which once read "0 spots left"; the full game must
    /// be one Explore lists, since the private group's game is not.
    @Test func feedSizedFixturesIncludeAFullEvent() {
        let events = MockEventFixtures.make(now: .now, count: AppConfig.Events.mockFeedSize).filter(\.isListed)
        #expect(events.contains { $0.isFull })
    }

    /// The feed should show every capacity state of the bar: an open, a nearly full (amber) and a full event.
    @Test func feedSizedFixturesCoverEveryCapacityState() {
        let events = MockEventFixtures.make(now: .now, count: AppConfig.Events.mockFeedSize).filter(\.isListed)
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

        #expect(logger.messages(in: .location, at: .info) == ["User location available", "User location changed"])
        #expect(logger.messages(in: .location, at: .debug) == ["No user location", "User location unchanged"])
    }
}
