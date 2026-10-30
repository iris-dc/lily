import SwiftUI

/// The Explore tab: the upcoming games as a list or a map, with the public groups to discover in a carousel above the
/// list. The list and the carousels draw the app-lifetime view models of `ShellLists`, which `ShellSync` loads right
/// after launch, so the tab's first frame has content (the last run's snapshot at the least); the appearance tasks
/// here keep them fresh: Discover searches again after a group changed anywhere (a join, a leave, a create), the
/// tournaments reload on a tournament change, and both carousels ask for the position, since the backend orders what
/// they show by distance and the tiles show it. The carousels keep a failure to themselves because the list reports
/// its own.
struct ExploreTab: View {
    let dependencies: AppDependencies

    private var discover: DiscoverGroupsViewModel { dependencies.lists.discover }
    private var tournaments: TournamentListViewModel { dependencies.lists.exploreTournaments }

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
        EventListView(listTitle: showsGroups || showsTournaments ? AppBranding.Events.eventsSection : nil,
                      viewModel: dependencies.lists.exploreEvents,
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
