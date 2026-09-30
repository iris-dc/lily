import SwiftUI
import UIKit

struct MainTabView: View {
    let dependencies: AppDependencies

    /// Rooms with unread messages plus the inbox when it holds something unseen: one badge for every conversation.
    private var unreadChats: Int {
        dependencies.unreadCenter.count + (dependencies.inbox.hasUnread ? 1 : 0)
    }

    var body: some View {
        @Bindable var navigation = dependencies.navigation
        TabView(selection: $navigation.selectedTab) {
            Tab(value: .home) {
                HomeTab(dependencies: dependencies)
            } label: {
                tabLabel(AppBranding.homeTitle, symbol: DesignTokens.Symbols.home)
            }
            Tab(value: .explore) {
                ExploreTab(dependencies: dependencies)
            } label: {
                tabLabel(AppBranding.exploreTitle, symbol: DesignTokens.Symbols.explore)
            }
            if AppConfig.FeatureFlags.chat {
                Tab(value: .chat) {
                    ChatTab(dependencies: dependencies)
                } label: {
                    tabLabel(AppBranding.chatsTitle, symbol: DesignTokens.Symbols.chat)
                }
                .badge(unreadChats)
                // A tab badge is not in the accessibility tree; the value says what it means and lets tests see it.
                .accessibilityValue(Text(AppBranding.Chats.unreadChats(unreadChats)), isEnabled: unreadChats > 0)
            }
            Tab(value: .profile) {
                ProfileView(session: dependencies.sessionController, errorCenter: dependencies.errorCenter)
            } label: {
                tabLabel(AppBranding.profileTitle, symbol: DesignTokens.Symbols.profile)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    /// A light outline glyph over the title. `Tab(_:systemImage:)` would draw the symbol at the bar's own heavy weight
    /// and fill it in both states; a `UIImage` with a symbol configuration is the one route the iOS 26 tab bar honours
    /// (`DesignTokens.TabBar`). The tab stays findable by its title.
    private func tabLabel(_ title: String, symbol: String) -> some View {
        let configuration = UIImage.SymbolConfiguration(weight: DesignTokens.TabBar.symbolWeight)
        return Label {
            Text(title)
        } icon: {
            Image(uiImage: UIImage(systemName: symbol, withConfiguration: configuration) ?? UIImage())
                .renderingMode(.template)
        }
    }
}

#Preview {
    MainTabView(dependencies: .makeMock())
}
