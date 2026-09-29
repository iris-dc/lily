import SwiftUI

/// A row of a conversation list (a group room on the Chats tab, the inbox): a mark, a title line, a one-line caption
/// and the unread dot, with the padding and hit shape every such row shares.
struct ConversationRow<Title: View>: View {
    let caption: String
    let hasUnread: Bool
    @ViewBuilder var avatar: () -> AvatarCircle
    @ViewBuilder var title: () -> Title

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            avatar()
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                title()
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(caption)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: DesignTokens.Spacing.sm)
            if hasUnread {
                UnreadDot()
            }
        }
        .padding(.vertical, DesignTokens.Spacing.md)
        .contentShape(.rect)
    }
}

/// The divider under a row led by a medium avatar (conversation rows, invite candidates): it starts at the text column,
/// as in Messages, rather than under the avatar.
struct AvatarRowDivider: View {
    var body: some View {
        Divider().padding(.leading, DesignTokens.Layout.avatarMedium + DesignTokens.Spacing.md)
    }
}
