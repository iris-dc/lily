import Foundation
import Testing
@testable import lily

/// The relevance wiring (2026-10-07): Explore's filter comes back from the defaults and `-reset-session` forgets it;
/// Discover and the group form get the location service. In a file of its own, the main suite being at its limit.
@MainActor
struct AppDependenciesRelevanceTests {
    private let defaults = makeTestDefaults()
    private let logger = SpyLogger()

    private var stored: UserDefaultsEventFilterStore { UserDefaultsEventFilterStore(defaults: defaults, logger: logger) }

    private static func makeFilter() -> EventFilter {
        var filter = EventFilter()
        filter.toggle(.yoga)
        filter.maxDistanceMeters = nil
        return filter
    }

    /// Explore starts from the stored filter; the lists without a filter button start from `.everything` and store nothing.
    @Test func exploreRestoresTheStoredFilterAndKeepsItsChanges() {
        stored.save(Self.makeFilter())
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents], defaults: defaults)

        let explore = dependencies.makeEventListViewModel(scope: .upcoming)
        #expect(explore.filter == Self.makeFilter())
        explore.toggleType(.tennis)
        #expect(stored.load()?.types == [.yoga, .tennis])

        let home = dependencies.makeEventListViewModel(scope: .joined)
        #expect(home.filter == .everything)
        home.toggleType(.padel)
        #expect(stored.load()?.types == [.yoga, .tennis], "Home's filter is never stored")
    }

    @Test func aFreshInstallStartsFromTheDefaultsAndResetSessionForgetsTheFilter() {
        #expect(AppDependencies.makeEventFilterStore(arguments: [], defaults: defaults, logger: logger).load() == nil)
        let fresh = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents], defaults: defaults)
        #expect(fresh.makeEventListViewModel(scope: .upcoming).filter == EventFilter())

        stored.save(Self.makeFilter())
        let reset = AppDependencies.makeEventFilterStore(arguments: [AppConfig.LaunchArguments.resetSession],
                                                         defaults: defaults,
                                                         logger: logger)
        #expect(reset.load() == nil && stored.load() == nil)
        #expect(AppDependencies.makeMock().eventFilterStore is NoOpEventFilterStore, "previews store nothing")
    }

    /// Discover asks the shared location service for the position it sends and shows distances by; the group form
    /// proposes it as the spot.
    @Test func discoverAndTheGroupFormTakeTheLocationService() async {
        let dependencies = AppDependencies.makeMock()

        let discover = dependencies.makeGroupListViewModel(scope: .discover)
        await discover.loadUserLocation()
        #expect(discover.userLocation == AppConfig.Location.mockCenter)
        await discover.loadIfStale()
        #expect(discover.groups.first?.name == "Spree Volley", "nearest first around the mock centre")
        #expect(discover.distanceText(for: discover.groups[0]) != nil)

        let create = dependencies.makeCreateGroupViewModel { _ in }
        await create.prepare()
        #expect(create.draft.coordinate == AppConfig.Location.mockCenter)
    }
}
