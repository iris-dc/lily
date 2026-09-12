import SwiftUI

struct MainTabView: View {
    let dependencies: AppDependencies

    var body: some View {
        TabView {
            Tab(AppBranding.exploreTitle, systemImage: DesignTokens.Symbols.explore) {
                EventListView(
                    title: AppBranding.exploreTitle,
                    emptyState: EmptyStateView(symbolName: DesignTokens.Symbols.explore,
                                               title: AppBranding.exploreEmptyTitle,
                                               message: AppBranding.exploreEmptyMessage),
                    showsMap: true,
                    filterable: true,
                    creatable: true,
                    scope: .upcoming,
                    dependencies: dependencies
                )
            }
            Tab(AppBranding.myEventsTitle, systemImage: DesignTokens.Symbols.myEvents) {
                MyEventsTab(dependencies: dependencies)
            }
            Tab(AppBranding.profileTitle, systemImage: DesignTokens.Symbols.profile) {
                ProfileView(session: dependencies.sessionController, errorCenter: dependencies.errorCenter)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

#Preview {
    MainTabView(dependencies: .makeMock())
}
