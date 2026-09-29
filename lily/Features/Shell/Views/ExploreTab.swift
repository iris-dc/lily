import SwiftUI

/// The Explore tab: the upcoming games as a list or a map, with the public groups to discover in a carousel above the
/// list. The carousel's Discover view model lives here so it survives the list's own state changes; it searches once
/// per caller and again after a group changed anywhere (a join, a leave, a create), and keeps a failure to itself
/// because the list reports its own.
struct ExploreTab: View {
    private let dependencies: AppDependencies
    @State private var discover: GroupListViewModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        let discover = dependencies.makeGroupListViewModel(scope: .discover)
        discover.reportsSearchFailures = false
        _discover = State(initialValue: discover)
    }

    private var showsGroups: Bool { AppConfig.FeatureFlags.groups && !discover.groups.isEmpty }

    @ViewBuilder
    private func carousel() -> some View {
        if AppConfig.FeatureFlags.groups {
            GroupCarousel(viewModel: discover)
        }
    }

    private func refreshCarousel() async {
        if AppConfig.FeatureFlags.groups { await discover.refresh() }
    }

    var body: some View {
        EventListView(title: AppBranding.exploreTitle,
                      emptyState: EmptyStateView(symbolName: DesignTokens.Symbols.explore,
                                                 title: AppBranding.exploreEmptyTitle,
                                                 message: AppBranding.exploreEmptyMessage),
                      listTitle: showsGroups ? AppBranding.Events.gamesSection : nil,
                      showsMap: true,
                      filterable: true,
                      creatable: true,
                      scope: .upcoming,
                      dependencies: dependencies,
                      refreshHeader: refreshCarousel,
                      header: carousel)
        .task(id: dependencies.groupChanges.version) {
            if AppConfig.FeatureFlags.groups { await discover.loadIfStale() }
        }
    }
}

#Preview {
    ExploreTab(dependencies: .makeMock())
}
