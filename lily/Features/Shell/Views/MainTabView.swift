import SwiftUI
import UIKit

/// The shell's tabs. Copy is read into views as plain strings, so a new language rebuilds the trees of Home, Explore
/// and Chats (`.id(language)`) while the bar itself only re-renders its titles: a rebuilt bar slid its indicator in from
/// the first tab and drew the glyphs at its own heavy weight until the tab was tapped again. The profile is no tab: the
/// corner button on every tab root presents it as a sheet mounted here, above each tab's `.id(language)` — a language
/// picked inside it rebuilds the tabs underneath while the sheet, whose content takes the language as an input,
/// re-renders in place — and inside the root's `.id(shellGeneration)`, so a session end tears it down twice over (the
/// flag clears in `sessionDidEnd()` and the generation bump rebuilds this view). The root keeps this view for the
/// app's lifetime, under the landing while signed out; the tabs hold nothing then (`showsContent`), so no screen loads
/// or asks for the position behind the landing.
struct MainTabView: View {
    let dependencies: AppDependencies
    let showsContent: Bool
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
                content { HomeTab(dependencies: dependencies).id(language) }
            } label: {
                tabLabel(for: .home, symbol: DesignTokens.Symbols.home)
            }
            Tab(value: .explore) {
                content { ExploreTab(dependencies: dependencies).id(language) }
            } label: {
                tabLabel(for: .explore, symbol: DesignTokens.Symbols.explore)
            }
            if AppConfig.FeatureFlags.chat {
                Tab(value: .chat) {
                    content { ChatTab(dependencies: dependencies).id(language) }
                } label: {
                    tabLabel(for: .chat, symbol: DesignTokens.Symbols.chat)
                }
                .badge(unreadChats)
                // A tab badge is not in the accessibility tree; the value says what it means and lets tests see it.
                .accessibilityValue(Text(AppBranding.Chats.unreadChats(unreadChats)), isEnabled: unreadChats > 0)
            }
        }
        // iPadOS draws the tabs as a top bar on its own; the iPhone keeps its floating bar. `.sidebarAdaptable` was tried
        // and dropped: its sidebar only repeated the tabs and iPadOS opened it by itself in landscape,
        // taking 280 pt from the content column.
        .tabBarMinimizeBehavior(.onScrollDown)
        // The tabs fill and the bar shows at once, under the landing that the root fades out over them; animated, the
        // bar would slide up into view.
        .animation(nil, value: showsContent)
        // The navigation model stays ignorant of size classes; the shell tells it which Chats layout is on screen.
        .onChange(of: layoutMode.isRegular, initial: true) {
            dependencies.navigation.usesSplitChats = layoutMode.isRegular
        }
        // The profile sheet, presented once for the whole shell; the corner button on every tab root raises the flag.
        .sheet(isPresented: $navigation.isProfilePresented) {
            ProfileView(dependencies: dependencies, language: language)
        }
    }

    /// A tab's screen, or nothing while the landing covers the shell; the bar hides then, which keeps it built, so it
    /// is out of the accessibility tree without being rebuilt when the shell comes back.
    @ViewBuilder
    private func content(@ViewBuilder _ screen: () -> some View) -> some View {
        if showsContent {
            screen()
        } else {
            Color.clear.toolbarVisibility(.hidden, for: .tabBar)
        }
    }

    /// A light outline glyph over the title. `Tab(_:systemImage:)` would draw the symbol at the bar's own heavy weight
    /// and fill it in both states; a `UIImage` with a symbol configuration is the one route the iOS 26 tab bar honours
    /// (`DesignTokens.TabBar`). The tab stays findable by its title, the one `AppTab.title` the shortcuts menu names it by.
    private func tabLabel(for tab: AppTab, symbol: String) -> some View {
        let configuration = UIImage.SymbolConfiguration(weight: DesignTokens.TabBar.symbolWeight)
        return Label {
            Text(tab.title)
        } icon: {
            Image(uiImage: UIImage(systemName: symbol, withConfiguration: configuration) ?? UIImage())
                .renderingMode(.template)
        }
    }
}

#Preview {
    MainTabView(dependencies: .makeMock(), showsContent: true)
}
