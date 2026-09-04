import SwiftUI

struct MainTabView: View {
    let dependencies: AppDependencies

    var body: some View {
        TabView {
            Tab("Explore", systemImage: DesignTokens.Symbols.explore) {
                EventListView(
                    title: "Explore",
                    subtitle: "Games near you this week.",
                    emptyState: EmptyStateView(symbolName: DesignTokens.Symbols.explore,
                                               title: "Nothing yet",
                                               message: "New games show up here as people create them."),
                    viewModel: dependencies.makeEventListViewModel(scope: .upcoming)
                )
            }
            Tab("My Events", systemImage: DesignTokens.Symbols.myEvents) {
                EventListView(
                    title: "My Events",
                    emptyState: EmptyStateView(symbolName: DesignTokens.Symbols.addEvent,
                                               title: "No events yet",
                                               message: "Games you join or host will appear here."),
                    viewModel: dependencies.makeEventListViewModel(scope: .joined)
                )
            }
            Tab("Profile", systemImage: DesignTokens.Symbols.profile) {
                ProfileView(session: dependencies.sessionController)
            }
            Tab(role: .search) {
                EventListView(
                    title: "Search",
                    emptyState: EmptyStateView(symbolName: DesignTokens.Symbols.search,
                                               title: "No matches",
                                               message: "Try another sport, place or title."),
                    searchable: true,
                    viewModel: dependencies.makeEventListViewModel(scope: .upcoming)
                )
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

#Preview {
    MainTabView(dependencies: .makeMock())
}
