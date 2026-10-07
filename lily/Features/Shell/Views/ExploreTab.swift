import SwiftUI

/// The Explore tab: the upcoming games as a list or a map, with the public groups to discover in a carousel above the
/// list. The carousel's Discover view model lives here so it survives the list's own state changes; it searches once
/// per caller and position and again after a group changed anywhere (a join, a leave, a create), and keeps a failure
/// to itself because the list reports its own. Both carousels ask for the position on appearance: the backend orders
/// what they show by distance, and the tiles show it.
struct ExploreTab: View {
    private let dependencies: AppDependencies
    @State private var discover: GroupListViewModel
    /// The public tournaments open for entries, under the groups; it keeps a failure to itself like Discover does.
    @State private var tournaments: TournamentListViewModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        let discover = dependencies.makeGroupListViewModel(scope: .discover)
        discover.reportsSearchFailures = false
        _discover = State(initialValue: discover)
        let tournaments = dependencies.makeTournamentListViewModel(scope: .upcoming)
        tournaments.reportsFailures = false
        _tournaments = State(initialValue: tournaments)
    }

    private var showsGroups: Bool { AppConfig.FeatureFlags.groups && !discover.groups.isEmpty }
    private var showsTournaments: Bool { AppConfig.FeatureFlags.tournaments && !tournaments.visibleTournaments.isEmpty }

    @ViewBuilder
    private func carousels() -> some View {
        if AppConfig.FeatureFlags.groups {
            GroupCarousel(viewModel: discover)
        }
        if AppConfig.FeatureFlags.tournaments {
            TournamentCarousel(viewModel: tournaments)
        }
    }

    private func refreshCarousels() async {
        if AppConfig.FeatureFlags.groups { await discover.refresh() }
        if AppConfig.FeatureFlags.tournaments { await tournaments.load() }
    }

    var body: some View {
        EventListView(title: AppBranding.exploreTitle,
                      emptyState: EmptyStateView(symbolName: DesignTokens.Symbols.explore,
                                                 title: AppBranding.exploreEmptyTitle,
                                                 message: AppBranding.exploreEmptyMessage),
                      listTitle: showsGroups || showsTournaments ? AppBranding.Events.eventsSection : nil,
                      showsMap: true,
                      filterable: true,
                      creatable: true,
                      scope: .upcoming,
                      dependencies: dependencies,
                      refreshHeader: refreshCarousels,
                      header: carousels)
        .task(id: dependencies.groupChanges.version) {
            if AppConfig.FeatureFlags.groups { await discover.loadIfStale() }
        }
        .task(id: dependencies.tournamentChanges.version) {
            if AppConfig.FeatureFlags.tournaments { await tournaments.loadIfStale() }
        }
        .task {
            if AppConfig.FeatureFlags.groups { await discover.loadUserLocation() }
            if AppConfig.FeatureFlags.tournaments { await tournaments.loadUserLocation() }
        }
    }
}

#Preview {
    ExploreTab(dependencies: .makeMock())
}
