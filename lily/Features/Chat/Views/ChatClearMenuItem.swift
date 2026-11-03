import SwiftUI

/// The one destructive item of a Chats row's context menu, for anyone who may chat: it clears a group's history or
/// deletes a conversation, worded by `ChatClearPrompt` for the room's kind (the caller stays a member; Leave is on the
/// detail), and asks through `chatClearConfirmation` before anything is sent. The room itself offers no menu: clearing
/// is the list's.
struct ChatClearMenuItem: View {
    let group: SportGroup
    let action: () -> Void

    var body: some View {
        let prompt = ChatClearPrompt(group: group)
        Button(prompt.actionTitle,
               systemImage: DesignTokens.Symbols.clearChat,
               role: .destructive,
               action: action)
            .accessibilityIdentifier(AccessibilityIdentifiers.chatClear)
    }
}

/// The confirmation a Chats row asks, worded by `ChatClearPrompt`: an alert in the middle of the screen (a confirmation
/// dialog opens as a popover at its anchor's corner). `group` is the room awaiting the caller's word, `nil` while
/// nothing is asked. An alert's buttons take the presenting view's tint and ignore their own, and a destructive one is
/// always the system's red, so the alert hangs off a helper tinted white: Cancel reads white, Delete chat red, and the
/// screen's accent toolbar keeps its colour.
private struct ChatClearConfirmation: ViewModifier {
    @Binding var group: SportGroup?
    let onConfirm: (SportGroup) -> Void

    func body(content: Content) -> some View {
        content.background {
            Color.clear
                .alert(item: $group,
                       title: { ChatClearPrompt(group: $0).title },
                       actions: { group in
                           Button(AppBranding.Forms.cancel, role: .cancel) {}
                           Button(ChatClearPrompt(group: group).actionTitle, role: .destructive) { onConfirm(group) }
                       },
                       message: { Text(ChatClearPrompt(group: $0).message) })
                .tint(.white)
        }
    }
}

extension View {
    /// Asks before a chat is cleared or deleted; `onConfirm` receives the room once the caller agreed.
    func chatClearConfirmation(for group: Binding<SportGroup?>, onConfirm: @escaping (SportGroup) -> Void) -> some View {
        modifier(ChatClearConfirmation(group: group, onConfirm: onConfirm))
    }
}
