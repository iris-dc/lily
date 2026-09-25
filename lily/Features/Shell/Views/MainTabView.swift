import SwiftUI

struct MainTabView: View {
    let dependencies: AppDependencies

    var body: some View {
        @Bindable var navigation = dependencies.navigation
        TabView(selection: $navigation.selectedTab) {
            Tab(AppBranding.exploreTitle, systemImage: DesignTokens.Symbols.explore, value: .explore) {
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
            Tab(AppBranding.myEventsTitle, systemImage: DesignTokens.Symbols.myEvents, value: .myEvents) {
                MyEventsTab(dependencies: dependencies)
            }
            if AppConfig.FeatureFlags.groups {
                let unreadRooms = dependencies.unreadCenter.count
                Tab(AppBranding.Groups.title, systemImage: DesignTokens.Symbols.groups, value: .groups) {
                    GroupsTab(dependencies: dependencies)
                }
                .badge(unreadRooms)
                // A tab badge is not in the accessibility tree; the value says what it means and lets tests see it.
                .accessibilityValue(Text(AppBranding.Groups.unreadRooms(unreadRooms)), isEnabled: unreadRooms > 0)
            }
            Tab(AppBranding.profileTitle, systemImage: DesignTokens.Symbols.profile, value: .profile) {
                ProfileView(session: dependencies.sessionController, errorCenter: dependencies.errorCenter)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

#Preview {
    MainTabView(dependencies: .makeMock())
}
