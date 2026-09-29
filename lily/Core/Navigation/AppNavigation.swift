import Observation
import SwiftUI

/// The shell's navigation state: the selected tab and the Home stack's path. Anything presented over the shell (an
/// invite preview, a group detail's "Open chat") selects a tab and pushes through it, so the tab bar and the Home root
/// are the only views that bind to it. Reset on sign-out like every per-user state, or the next user would land on
/// the previous one's pushed screens.
@Observable
final class AppNavigation: SessionObserver {
    var selectedTab: AppTab = .explore
    var homePath = NavigationPath()

    /// Shows the Home tab with `destination` pushed onto its stack.
    func openInHome(_ destination: some Hashable) {
        selectedTab = .home
        homePath.append(destination)
    }

    func open(group: SportGroup) {
        openInHome(group)
    }

    /// The group's chat; the group itself while chat is switched off, so the push still lands somewhere.
    func open(chat group: SportGroup) {
        if AppConfig.FeatureFlags.chat {
            openInHome(ChatDestination(group: group))
        } else {
            open(group: group)
        }
    }

    func popHomeToRoot() {
        homePath = NavigationPath()
    }

    /// Where a launch lands once the session is restored: a signed-in user on Home, their groups and games; everyone
    /// else on Explore, which is what the landing's button promises.
    static func startTab(for state: SessionState) -> AppTab {
        state.user == nil ? .explore : .home
    }

    func sessionDidEnd() {
        selectedTab = .explore
        popHomeToRoot()
    }
}
