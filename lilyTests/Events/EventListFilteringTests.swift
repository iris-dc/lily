import Foundation
import Testing
@testable import lily

/// The filter as seen through the view model: what the list and map render, which types the panel offers, and how the
/// distance criterion waits for the user's position.
@MainActor
struct EventListFilteringTests {
    @Test func visibleEventsFollowTheFilterWhileEventsStayComplete() async {
        let repository = FakeEventRepository()
        let events = MockEventFixtures.make(now: .now, count: 4)
        repository.result = .success(events)
        let viewModel = makeEventListViewModel(repository: repository)
        await viewModel.load()

        viewModel.toggleType(.football)
        #expect(viewModel.visibleEvents.map(\.type) == [.football])
        #expect(viewModel.events == events)
        #expect(!viewModel.isEverythingFilteredOut)

        viewModel.clearFilter()
        #expect(viewModel.visibleEvents == events)
    }

    @Test func everythingFilteredOutOnlyWhenEventsExistButNoneMatch() async {
        let repository = FakeEventRepository()
        repository.result = .success(MockEventFixtures.make(now: .now, count: 1))
        let viewModel = makeEventListViewModel(repository: repository)
        #expect(!viewModel.isEverythingFilteredOut)

        await viewModel.load()
        viewModel.toggleType(.climbing)
        #expect(viewModel.isEverythingFilteredOut)
        #expect(viewModel.visibleEvents.isEmpty)

        viewModel.clearFilter()
        #expect(!viewModel.isEverythingFilteredOut)
    }

    @Test func filterSurvivesAReload() async {
        let repository = FakeEventRepository()
        repository.result = .success(MockEventFixtures.make(now: .now, count: 3))
        let viewModel = makeEventListViewModel(repository: repository)
        await viewModel.load()
        viewModel.toggleType(.basketball)

        await viewModel.load()
        #expect(viewModel.filter.includes(.basketball))
        #expect(viewModel.visibleEvents.map(\.type) == [.basketball])
    }

    @Test func aSelectedTypeSurvivesAReloadThatDroppedItsGames() async {
        let repository = FakeEventRepository()
        let all = MockEventFixtures.make(now: .now, count: 8)
        repository.result = .success(all.filter { [.football, .basketball].contains($0.type) })
        let viewModel = makeEventListViewModel(repository: repository)
        await viewModel.load()
        viewModel.toggleType(.basketball)

        repository.result = .success(all.filter { $0.type == .football })
        await viewModel.load()

        #expect(viewModel.filter.includes(.basketball))
        #expect(viewModel.isEverythingFilteredOut)
        viewModel.toggleType(.basketball)
        #expect(viewModel.visibleEvents.map(\.type) == [.football])
    }

    @Test func distanceCriterionUsesTheUserPositionOnceKnown() async {
        let repository = FakeEventRepository()
        repository.result = .success(MockEventFixtures.make(now: .now, count: 8))
        let viewModel = makeEventListViewModel(repository: repository,
                                               locationService: MockLocationService(coordinate: AppConfig.Location.mockCenter))
        await viewModel.load()
        viewModel.updateFilter { $0.maxDistanceMeters = 2_500 }
        #expect(viewModel.visibleEvents.count == 8, "no position yet, so distance is not judged")

        await viewModel.loadUserLocation()
        #expect(viewModel.visibleEvents.count < 8)
        #expect(viewModel.visibleEvents.allSatisfy {
            $0.location.coordinate.distance(to: AppConfig.Location.mockCenter) <= 2_500
        })
    }

    /// Home has no filter button, so it must start from `.everything` and never hide a joined game far away.
    @Test func aListStartedFromEverythingShowsFarAwayGames() async {
        let repository = FakeEventRepository()
        repository.result = .success(MockEventFixtures.make(now: .now, count: 3))
        let far = Coordinate(latitude: AppConfig.Location.mockCenter.latitude + 0.5,
                             longitude: AppConfig.Location.mockCenter.longitude)
        let viewModel = makeEventListViewModel(scope: .joined,
                                               repository: repository,
                                               locationService: MockLocationService(coordinate: far),
                                               initialFilter: .everything)
        await viewModel.load()
        await viewModel.loadUserLocation()
        #expect(viewModel.visibleEvents.count == 3)
        #expect(!viewModel.isEverythingFilteredOut)
    }

    /// One panel session is one `filter_applied`, and only when it changed something; undoing a change inside the
    /// session leaves nothing to report.
    @Test func closingThePanelRecordsTheFilterOnlyWhenItChanged() {
        let recorder = SpyInteractionRecorder()
        let viewModel = makeEventListViewModel(repository: FakeEventRepository(), recorder: recorder)

        viewModel.filterPanelOpened()
        viewModel.filterPanelClosed()
        #expect(recorder.interactions.isEmpty)

        viewModel.filterPanelOpened()
        viewModel.toggleType(.padel)
        viewModel.updateFilter { $0.maxPrice = 10 }
        viewModel.filterPanelClosed()
        #expect(recorder.kinds == [.filterApplied])
        #expect(recorder.interactions.first?.filter == FilterSummary(viewModel.filter))
        #expect(recorder.interactions.first?.filter?.types == ["padel"])
        #expect(recorder.interactions.first?.filter?.hasMaxPrice == true)

        viewModel.filterPanelOpened()
        viewModel.toggleType(.padel)
        viewModel.toggleType(.padel)
        viewModel.filterPanelClosed()
        #expect(recorder.interactions.count == 1)
    }

    /// The empty state's "Show all events" is a filter the user applied without the panel.
    @Test func showEverythingRecordsTheFilterItApplies() {
        let recorder = SpyInteractionRecorder()
        let viewModel = makeEventListViewModel(repository: FakeEventRepository(), recorder: recorder)

        viewModel.showEverything()

        #expect(recorder.interactions.map(\.filter) == [FilterSummary(.everything)])
    }

    @Test func switchingThePresentationIsRecorded() {
        let recorder = SpyInteractionRecorder()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = makeEventListViewModel(repository: FakeEventRepository(), recorder: recorder, now: { now })

        viewModel.presentationChanged(to: .map)

        #expect(recorder.interactions == [.presentationChanged(.map, at: now)])
    }

    @Test func showEverythingIsTheWayOutWhenTheDefaultsHideEveryGame() async {
        let repository = FakeEventRepository()
        repository.result = .success(MockEventFixtures.make(now: .now, count: 3))
        let far = Coordinate(latitude: AppConfig.Location.mockCenter.latitude + 0.5,
                             longitude: AppConfig.Location.mockCenter.longitude)
        let viewModel = makeEventListViewModel(repository: repository, locationService: MockLocationService(coordinate: far))
        await viewModel.load()
        await viewModel.loadUserLocation()
        #expect(viewModel.isEverythingFilteredOut)
        #expect(!viewModel.filter.isActive, "the defaults alone hide everything, so Reset would not help")

        viewModel.showEverything()
        #expect(viewModel.visibleEvents.count == 3)
    }
}
