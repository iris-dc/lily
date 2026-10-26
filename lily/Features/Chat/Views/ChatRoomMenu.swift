import SwiftUI

/// The room's "more" menu, for anyone who may chat: one destructive item that clears a group's history or deletes a
/// conversation, worded by `ChatClearPrompt` (the caller stays a member; Leave is on the detail). The item is
/// `ChatClearMenuItem`, which the Chats rows' context menu reuses, and both ask through `chatClearConfirmation` before
/// anything is sent.
struct ChatRoomMenu: View {
    let group: SportGroup
    let userID: String?
    let onClear: () -> Void

    var body: some View {
        if GroupAccess(group: group, userID: userID).canChat {
            Menu {
                ChatClearMenuItem(group: group, action: onClear)
            } label: {
                Label(AppBranding.Chat.more, systemImage: DesignTokens.Symbols.more)
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.chatMore)
        }
    }
}

/// The clear or delete item, worded by `ChatClearPrompt` for the room's kind.
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

/// The confirmation the room's menu and a Chats row share, worded by `ChatClearPrompt`: an alert in the middle of the
/// screen, since a confirmation dialog asked from the room's toolbar menu opened as a popover at its corner. `group` is
/// the room awaiting the caller's word, `nil` while nothing is asked.
private struct ChatClearConfirmation: ViewModifier {
    @Binding var group: SportGroup?
    let onConfirm: (SportGroup) -> Void

    func body(content: Content) -> some View {
        content.alert(item: $group,
                      title: { ChatClearPrompt(group: $0).title },
                      actions: { group in
                          Button(AppBranding.Forms.cancel, role: .cancel) {}
                          Button(ChatClearPrompt(group: group).actionTitle, role: .destructive) { onConfirm(group) }
                      },
                      message: { Text(ChatClearPrompt(group: $0).message) })
    }
}

extension View {
    /// Asks before a chat is cleared or deleted; `onConfirm` receives the room once the caller agreed.
    func chatClearConfirmation(for group: Binding<SportGroup?>, onConfirm: @escaping (SportGroup) -> Void) -> some View {
        modifier(ChatClearConfirmation(group: group, onConfirm: onConfirm))
    }
}
