import SwiftUI

/// The inbox as the first row of the Chats tab: the app's mark, its name, the newest item in one line (or what the
/// inbox is for while it is empty) and the unread dot. A `NavigationLink` to the inbox.
struct InboxRow: View {
    let inbox: InboxStore

    var body: some View {
        NavigationLink(value: InboxDestination()) {
            ConversationRow(caption: caption, hasUnread: inbox.hasUnread) {
                AvatarCircle(initials: "", systemImage: DesignTokens.Symbols.inbox, size: DesignTokens.Layout.avatarMedium)
            } title: {
                Text(AppBranding.Inbox.title)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityIdentifiers.inboxRow)
    }

    private var caption: String {
        inbox.newestVisible?.caption ?? AppBranding.Inbox.emptyCaption
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        ContentScreen {
            InboxRow(inbox: dependencies.inbox).padding(.horizontal, DesignTokens.Layout.screenMargin)
        }
    }
}
