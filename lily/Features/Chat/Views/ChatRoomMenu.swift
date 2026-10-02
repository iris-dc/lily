import SwiftUI

/// The room's "more" menu, for anyone who may chat: one destructive item, "Clear chat" for a group (the caller stays a
/// member; Leave is on the detail) or "Delete chat" for a conversation. The item is `ChatClearMenuItem`, which the
/// Chats rows' context menu reuses, and both ask through `chatClearConfirmation` before anything is sent.
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

/// The clear or delete item, worded for the room's kind.
struct ChatClearMenuItem: View {
    let group: SportGroup
    let action: () -> Void

    var body: some View {
        Button(group.isDirect ? AppBranding.Chat.deleteChat : AppBranding.Chat.clearChat,
               systemImage: DesignTokens.Symbols.clearChat,
               role: .destructive,
               action: action)
            .accessibilityIdentifier(AccessibilityIdentifiers.chatClear)
    }
}

/// The confirmation the room's menu and a Chats row share: title, message and action worded for a group ("the messages
/// disappear for you only") or a conversation (it comes back without the old messages if the other person writes).
/// `group` is the room awaiting the caller's word, `nil` while nothing is asked.
private struct ChatClearConfirmation: ViewModifier {
    @Binding var group: SportGroup?
    let onConfirm: (SportGroup) -> Void

    private typealias Copy = AppBranding.Chat

    func body(content: Content) -> some View {
        content.confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible, presenting: group) { group in
            Button(role: .destructive) {
                onConfirm(group)
            } label: {
                Text(group.isDirect ? Copy.deleteChat : Copy.clearChat)
            }
        } message: { group in
            Text(group.isDirect ? Copy.deleteConfirmationMessage(name: group.name) : Copy.clearConfirmationMessage)
        }
    }

    private var isPresented: Binding<Bool> {
        Binding(get: { group != nil }, set: { if !$0 { group = nil } })
    }

    private var title: String {
        guard let group else { return "" }
        return group.isDirect ? Copy.deleteConfirmationTitle(name: group.name) : Copy.clearConfirmationTitle
    }
}

extension View {
    /// Asks before a chat is cleared or deleted; `onConfirm` receives the room once the caller agreed.
    func chatClearConfirmation(for group: Binding<SportGroup?>, onConfirm: @escaping (SportGroup) -> Void) -> some View {
        modifier(ChatClearConfirmation(group: group, onConfirm: onConfirm))
    }
}
