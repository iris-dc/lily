import Observation
import SwiftUI

/// The shell's navigation state: the selected tab and the paths of the Home and Chats stacks. Anything that opens a
/// screen from elsewhere (a group detail's "Open chat", an accepted invite, a system row's game) selects a tab and
/// pushes through it, so the tab bar and the two stack roots are the only views that bind to it. Reset on sign-out
/// like every per-user state, or the next user would land on the previous one's pushed screens.
@Observable
final class AppNavigation: SessionObserver {
    var selectedTab: AppTab = .explore
    var homePath = NavigationPath()
    var chatPath = NavigationPath()

    /// Shows the Home tab with `destination` pushed onto its stack.
    func openInHome(_ destination: some Hashable) {
        selectedTab = .home
        homePath.append(destination)
    }

    /// Shows the Chats tab with `destination` pushed onto its stack.
    func openInChat(_ destination: some Hashable) {
        selectedTab = .chat
        chatPath.append(destination)
    }

    /// The group's detail, on Home: memberships and plans live there.
    func open(group: SportGroup) {
        openInHome(group)
    }

    /// A tournament's detail, on Home: entries and plans live there like a group's.
    func open(tournament destination: TournamentDestination) {
        openInHome(destination)
    }

    /// The group's chat, on the Chats tab; the group itself while chat is switched off, so the push still lands somewhere.
    func open(chat group: SportGroup) {
        if AppConfig.FeatureFlags.chat {
            openInChat(ChatDestination(group: group))
        } else {
            open(group: group)
        }
    }

    func popHomeToRoot() {
        homePath = NavigationPath()
    }

    func popChatToRoot() {
        chatPath = NavigationPath()
    }

    /// Where a launch lands once the session is restored: a signed-in user on Home, their groups and games; everyone
    /// else on Explore, which is what the landing's button promises.
    static func startTab(for state: SessionState) -> AppTab {
        state.user == nil ? .explore : .home
    }

    func sessionDidEnd() {
        selectedTab = .explore
        popHomeToRoot()
        popChatToRoot()
    }
}
