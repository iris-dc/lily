import Observation
import SwiftUI

/// The shell's navigation state: the selected tab and the Groups stack's path. Anything presented over the shell (an
/// invite preview, the tab badge) selects a tab and pushes through it, so the tab bar and the Groups root are the
/// only views that bind to it. Reset on sign-out like every per-user state, or the next user would land on the
/// previous one's pushed screens.
@Observable
final class AppNavigation: SessionObserver {
    var selectedTab: AppTab = .explore
    var groupsPath = NavigationPath()

    /// Shows the Groups tab with `destination` pushed onto its stack.
    func openInGroups(_ destination: some Hashable) {
        selectedTab = .groups
        groupsPath.append(destination)
    }

    func open(group: SportGroup) {
        openInGroups(group)
    }

    /// The group's chat; the group itself while chat is switched off, so the push still lands somewhere.
    func open(chat group: SportGroup) {
        if AppConfig.FeatureFlags.chat {
            openInGroups(ChatDestination(group: group))
        } else {
            open(group: group)
        }
    }

    func popGroupsToRoot() {
        groupsPath = NavigationPath()
    }

    func sessionDidEnd() {
        selectedTab = .explore
        popGroupsToRoot()
    }
}
