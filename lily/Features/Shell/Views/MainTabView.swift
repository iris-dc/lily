import SwiftUI
import UIKit

/// The shell's four tabs. Copy is read into views as plain strings, so a new language rebuilds each tab's tree
/// (`.id(language)`) while the bar itself only re-renders its titles: a rebuilt bar slid its indicator in from the
/// first tab and drew the glyphs at its own heavy weight until the tab was tapped again.
struct MainTabView: View {
    let dependencies: AppDependencies
    @Environment(\.layoutMode) private var layoutMode

    private var language: AppLanguage { dependencies.language.language }

    /// Rooms with unread messages plus the inbox when it holds something unseen: one badge for every conversation.
    private var unreadChats: Int {
        dependencies.unreadCenter.count + (dependencies.inbox.hasUnread ? 1 : 0)
    }

    var body: some View {
        @Bindable var navigation = dependencies.navigation
        TabView(selection: $navigation.selectedTab) {
            Tab(value: .home) {
                HomeTab(dependencies: dependencies)
                    .id(language)
            } label: {
                tabLabel(AppBranding.homeTitle, symbol: DesignTokens.Symbols.home)
            }
            Tab(value: .explore) {
                ExploreTab(dependencies: dependencies)
                    .id(language)
            } label: {
                tabLabel(AppBranding.exploreTitle, symbol: DesignTokens.Symbols.explore)
            }
            if AppConfig.FeatureFlags.chat {
                Tab(value: .chat) {
                    ChatTab(dependencies: dependencies)
                    .id(language)
                } label: {
                    tabLabel(AppBranding.chatsTitle, symbol: DesignTokens.Symbols.chat)
                }
                .badge(unreadChats)
                // A tab badge is not in the accessibility tree; the value says what it means and lets tests see it.
                .accessibilityValue(Text(AppBranding.Chats.unreadChats(unreadChats)), isEnabled: unreadChats > 0)
            }
            Tab(value: .profile) {
                ProfileView(dependencies: dependencies)
                    .id(language)
            } label: {
                tabLabel(AppBranding.profileTitle, symbol: DesignTokens.Symbols.profile)
            }
        }
        // iPadOS draws the tabs as a top bar on its own; the iPhone keeps its floating bar. `.sidebarAdaptable` was tried
        // and dropped: its sidebar only repeated the four tabs and iPadOS opened it by itself in landscape,
        // taking 280 pt from the content column.
        .tabBarMinimizeBehavior(.onScrollDown)
        // The navigation model stays ignorant of size classes; the shell tells it which Chats layout is on screen.
        .onChange(of: layoutMode.isRegular, initial: true) {
            dependencies.navigation.usesSplitChats = layoutMode.isRegular
        }
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
