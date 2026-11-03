import SwiftUI

/// A row led by a medium mark (a room on the Chats tab, the inbox, a person to invite): the mark, a title line, a
/// one-line caption and a trailing slot (the unread dot, an Invite button), with the padding and hit shape every such
/// row shares. The mark is a concrete `AvatarCircle`, not a generic slot: `AvatarRowDivider` offsets its divider by
/// that size.
struct ConversationRow<Title: View, Trailing: View>: View {
    let caption: String
    let avatar: AvatarCircle
    @ViewBuilder var title: () -> Title
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            avatar
            CaptionedTitle(lines: [caption], title: title)
            Spacer(minLength: DesignTokens.Spacing.sm)
            trailing()
        }
        .padding(.vertical, DesignTokens.Spacing.md)
        .contentShape(.rect)
    }
}

extension ConversationRow where Trailing == UnreadDot? {
    init(caption: String,
         hasUnread: Bool,
         avatar: AvatarCircle,
         @ViewBuilder title: @escaping () -> Title) {
        self.init(caption: caption, avatar: avatar, title: title, trailing: {
            if hasUnread {
                UnreadDot()
            }
        })
    }
}

/// The divider under a row led by a medium avatar (conversation rows, invite candidates): it starts at the text column,
/// as in Messages, rather than under the avatar.
struct AvatarRowDivider: View {
    var body: some View {
        Divider().padding(.leading, DesignTokens.Layout.avatarMedium + DesignTokens.Spacing.md)
    }
}
