import Observation
import SwiftUI

/// The shell's navigation state: the selected tab, the paths of the Home and Chats stacks, and on a regular width the
/// conversation the Chats split view shows. Anything that opens a screen from elsewhere (a group detail's "Open chat",
/// an accepted invite, a system row's game, a keyboard shortcut) selects a tab and goes through it, so the tab bar and
/// the stack roots are the only views that bind to it. Reset on sign-out like every per-user state, or the next user
/// would land on the previous one's pushed screens.
@Observable
final class AppNavigation: SessionObserver {
    var selectedTab: AppTab = .explore
    var homePath = NavigationPath()
    var chatPath = NavigationPath()
    /// Whether the Chats tab draws the split view (regular width), where a room is selected rather than pushed. The
    /// shell keeps it in step with the window's layout; the model stays ignorant of size classes.
    var usesSplitChats = false
    /// The split view's detail: the inbox, a room, or nothing yet. Unused on a compact width.
    var selectedConversation: ConversationSelection?
    /// A create asked for by a shortcut, waiting for Explore to present its sheet.
    var pendingCreate: CreateIntent?

    /// Shows the Home tab with `destination` pushed onto its stack.
    func openInHome(_ destination: some Hashable) {
        selectedTab = .home
        homePath.append(destination)
    }

    /// Shows the Chats tab with `destination` pushed onto its stack (the detail column's stack on a regular width).
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

    /// The group's chat, on the Chats tab: selected in the split view's detail on a regular width, pushed otherwise;
    /// the group itself while chat is switched off, so the push still lands somewhere.
    func open(chat group: SportGroup) {
        guard AppConfig.FeatureFlags.chat else {
            open(group: group)
            return
        }
        if usesSplitChats {
            select(.room(id: group.id))
        } else {
            openInChat(ChatDestination(group: group))
        }
    }

    /// The inbox, on the Chats tab: selected in the split view's detail on a regular width, pushed otherwise.
    func openInbox() {
        if usesSplitChats {
            select(.inbox)
        } else {
            openInChat(InboxDestination())
        }
    }

    /// Explore with its create sheet for `intent`; Explore consumes the intent once it is on screen.
    func requestCreate(_ intent: CreateIntent) {
        selectedTab = .explore
        pendingCreate = intent
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
        selectedConversation = nil
        pendingCreate = nil
        popHomeToRoot()
        popChatToRoot()
    }

    /// Shows the Chats tab with the detail column at its root on `selection`; a screen pushed over the previous
    /// conversation would otherwise hide the new one.
    private func select(_ selection: ConversationSelection) {
        selectedTab = .chat
        popChatToRoot()
        selectedConversation = selection
    }
}
