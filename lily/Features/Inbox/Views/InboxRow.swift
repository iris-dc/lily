import SwiftUI

/// The inbox as the first row of the Chats tab: the app's mark, its name, the newest item in one line (or what the
/// inbox is for while it is empty) and the unread dot. A button, so the container decides whether a tap pushes the
/// inbox or selects it in a split view's detail; drawn as selected while the detail shows it.
struct InboxRow: View {
    let inbox: InboxStore
    var isSelected = false
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            ConversationRow(caption: caption, hasUnread: inbox.hasUnread) {
                AvatarCircle(initials: "", systemImage: DesignTokens.Symbols.inbox, size: DesignTokens.Layout.avatarMedium)
            } title: {
                Text(AppBranding.Inbox.title)
            }
            .selectedRowBackground(isSelected)
        }
        .buttonStyle(.plain)
        .lilyHoverable()
        .accessibilityIdentifier(AccessibilityIdentifiers.inboxRow)
    }

    private var caption: String {
        inbox.newestVisible?.caption ?? AppBranding.Inbox.emptyCaption
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    ContentScreen {
        InboxRow(inbox: dependencies.inbox, isSelected: true) {}
            .padding(.horizontal, DesignTokens.Layout.screenMargin)
    }
}
