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
}

@MainActor
struct EventListViewModelTests {
    private func makeViewModel(_ repository: FakeEventRepository,
                               location: Coordinate? = nil) -> (EventListViewModel, ErrorCenter) {
        let center = ErrorCenter(logger: SpyLogger())
        let viewModel = EventListViewModel(scope: .upcoming,
                                           repository: repository,
                                           locationService: MockLocationService(coordinate: location),
                                           errorCenter: center,
                                           logger: SpyLogger())
        return (viewModel, center)
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

    @Test func searchFiltersByTitleSportAndLocation() async {
        let repository = FakeEventRepository()
        repository.result = .success(MockEventFixtures.make(now: .now, count: 8))
        let (viewModel, _) = makeViewModel(repository)
        await viewModel.load()

        viewModel.searchText = "tennis"
        #expect(viewModel.filteredEvents.map(\.sport) == [.tennis])

        viewModel.searchText = "Canal"
        #expect(viewModel.filteredEvents.map(\.title) == ["Easy 8k loop"])

        viewModel.searchText = "   "
        #expect(viewModel.filteredEvents.count == 8)
    }
}

struct SportEventTests {
    @Test func fixturesLieWithinTheDemoRadius() {
        let center = AppConfig.Location.mockCenter
        for event in MockEventFixtures.make(now: .now, count: 8) {
            #expect(event.location.coordinate.distance(to: center) < 5_000)
        }
    }

    @Test func distanceIsNilWithoutOrigin() {
        let event = MockEventFixtures.make(now: .now, count: 1)[0]
        #expect(event.distance(from: nil) == nil)
        #expect(event.distance(from: event.location.coordinate)?.value == 0)
    }

    @Test func nearlyFullFollowsConfiguredRatio() {
        #expect(!makeEvent(capacity: 4, participants: 1).isNearlyFull)
        #expect(makeEvent(capacity: 4, participants: 3).isNearlyFull)
        #expect(!makeEvent(capacity: 4, participants: 4).isNearlyFull)
    }

    private func makeEvent(capacity: Int, participants: Int) -> SportEvent {
        SportEvent(
            id: "e",
            title: "t",
            sport: .tennis,
            startsAt: .now,
            location: EventLocation(name: "l", coordinate: AppConfig.Location.mockCenter),
            capacity: capacity,
            participantCount: participants,
            hostName: "h"
        )
    }

    @Test func capacityMath() {
        let event = makeEvent(capacity: 4, participants: 1)
        #expect(event.spotsLeft == 3)
        #expect(event.fillRatio == 0.25)
        #expect(!event.isFull)
    }

    @Test func fullEventReportsNoSpots() {
        let event = makeEvent(capacity: 4, participants: 4)
        #expect(event.isFull)
        #expect(event.spotsLeft == 0)
        #expect(event.fillRatio == 1)
    }

    @Test func zeroCapacityDoesNotDivideByZero() {
        let event = makeEvent(capacity: 0, participants: 0)
        #expect(event.fillRatio == 0)
        #expect(event.isFull)
    }
}
