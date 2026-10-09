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

    /// Every way the filter changes (a chip, the panel, the empty state's "show everything", a clear) is written to the
    /// store, so the next launch starts from it; the initial filter is whatever the composition root restored.
    @Test func everyFilterChangeIsStoredForTheNextLaunch() async {
        let store = InMemoryEventFilterStore()
        var restored = EventFilter()
        restored.toggle(.padel)
        let viewModel = makeEventListViewModel(repository: FakeEventRepository(), initialFilter: restored, filterStore: store)
        #expect(viewModel.filter == restored && store.saveCount == 0, "restoring is not a change")

        viewModel.toggleType(.tennis)
        #expect(store.stored?.types == [.padel, .tennis] && store.saveCount == 1)

        viewModel.updateFilter { $0.maxDistanceMeters = 25_000 }
        #expect(store.stored?.maxDistanceMeters == 25_000 && store.saveCount == 2)

        viewModel.showEverything()
        #expect(store.stored == .everything && store.saveCount == 3)

        viewModel.clearFilter()
        #expect(store.stored == EventFilter() && store.saveCount == 4)
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

    /// The cap is judged in the user's currency, read on every pass: a Polish user's "under 30" keeps the 20 zł game
    /// and leaves the euro one out, and switching the currency on Profile changes the visible games without a reload.
    @Test func thePriceCapIsJudgedInTheUsersCurrencyAsItIsNow() async {
        let repository = FakeEventRepository()
        repository.result = .success([
            SportEvent.fixture(id: "pln", price: Price(amount: 20, currencyCode: "PLN")),
            SportEvent.fixture(id: "eur", price: Price(amount: 5, currencyCode: "EUR")),
            SportEvent.fixture(id: "free"),
        ])
        var currency = "PLN"
        let viewModel = makeEventListViewModel(repository: repository,
                                               currencyCode: { currency },
                                               initialFilter: .everything)
        await viewModel.load()
        #expect(viewModel.priceCurrencyCode == "PLN")

        viewModel.updateFilter { $0.maxPrice = 30 }
        #expect(viewModel.visibleEvents.map(\.id) == ["pln", "free"])

        currency = "EUR"
        #expect(viewModel.priceCurrencyCode == "EUR")
        #expect(viewModel.visibleEvents.map(\.id) == ["eur", "free"])
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
