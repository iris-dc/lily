import SwiftUI

struct MainTabView: View {
    let dependencies: AppDependencies

    var body: some View {
        @Bindable var navigation = dependencies.navigation
        let unreadRooms = AppConfig.FeatureFlags.groups ? dependencies.unreadCenter.count : 0
        TabView(selection: $navigation.selectedTab) {
            Tab(AppBranding.homeTitle, systemImage: DesignTokens.Symbols.home, value: .home) {
                HomeTab(dependencies: dependencies)
            }
            .badge(unreadRooms)
            // A tab badge is not in the accessibility tree; the value says what it means and lets tests see it.
            .accessibilityValue(Text(AppBranding.Groups.unreadRooms(unreadRooms)), isEnabled: unreadRooms > 0)
            Tab(AppBranding.exploreTitle, systemImage: DesignTokens.Symbols.explore, value: .explore) {
                ExploreTab(dependencies: dependencies)
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
