import SwiftUI

struct MainTabView: View {
    let dependencies: AppDependencies

    /// Rooms with unread messages plus the inbox when it holds something unseen: one badge for every conversation.
    private var unreadChats: Int {
        dependencies.unreadCenter.count + (dependencies.inbox.hasUnread ? 1 : 0)
    }

    var body: some View {
        @Bindable var navigation = dependencies.navigation
        TabView(selection: $navigation.selectedTab) {
            Tab(AppBranding.homeTitle, systemImage: DesignTokens.Symbols.home, value: .home) {
                HomeTab(dependencies: dependencies)
            }
            Tab(AppBranding.exploreTitle, systemImage: DesignTokens.Symbols.explore, value: .explore) {
                ExploreTab(dependencies: dependencies)
            }
            if AppConfig.FeatureFlags.chat {
                Tab(AppBranding.chatsTitle, systemImage: DesignTokens.Symbols.chat, value: .chat) {
                    ChatTab(dependencies: dependencies)
                }
                .badge(unreadChats)
                // A tab badge is not in the accessibility tree; the value says what it means and lets tests see it.
                .accessibilityValue(Text(AppBranding.Chats.unreadChats(unreadChats)), isEnabled: unreadChats > 0)
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
