import SwiftUI

/// One member's message as a bubble: the caller's in the accent, trailing; everyone else's on the surface colour,
/// leading, with the sender's avatar and current name on the first bubble of a run (both open `profile`, the sender's,
/// as the view model frames it for this room) and the time under the last. A reply shows the quoted original above
/// its text; tapping the quote asks `onTapQuote` to find it. Pictures and videos show as a gallery above the words (or
/// as the bubble itself when there are no words) and files as cards under it; tapping a tile asks `onTapAttachment` to
/// open it, tapping a card downloads the file and asks `onOpenFile` to preview it. Plain fills, never glass: a chat
/// scrolls dozens of these at once. The row is an accessibility container, so what is inside keeps its own identifier.
struct MessageBubble: View {
    let row: MessageRow
    let profile: UserProfileDestination
    let loader: AttachmentLoader
    /// Whether this device knows the quoted original is gone (`ChatViewModel.quoteIsDeleted`).
    var isQuoteDeleted = false
    var onTapQuote: (ReplyQuote) -> Void = { _ in }
    var onTapAttachment: (Attachment) -> Void = { _ in }
    var onOpenFile: (URL) -> Void = { _ in }

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            if !row.isOwn { avatarColumn }
            VStack(alignment: side.horizontal, spacing: DesignTokens.Spacing.xs) {
                if row.isFirstInRun, !row.isOwn { senderName }
                bubble
                if row.isLastInRun { timestamp }
            }
        }
        .bubbleRow(side: side)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private var side: Alignment { row.isOwn ? .trailing : .leading }

    /// Only the first bubble of a run shows the avatar; the rest keep its column so the run lines up. The name link
    /// speaks for both, so the avatar's stays out of the accessibility tree.
    @ViewBuilder private var avatarColumn: some View {
        if row.isFirstInRun {
            profileLink {
                AvatarCircle(initials: row.senderName.initials,
                             size: DesignTokens.Layout.avatarSmall,
                             tint: .lilySecondary,
                             tintOpacity: DesignTokens.Opacity.secondaryGlassTint)
            }
            .accessibilityHidden(true)
        } else {
            Color.clear.frame(width: DesignTokens.Layout.avatarSmall, height: 0)
        }
    }

    private var senderName: some View {
        profileLink {
            Text(row.senderName)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func profileLink(@ViewBuilder _ label: () -> some View) -> some View {
        NavigationLink(value: profile) {
            label()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var bubble: some View {
        if row.message.isDeleted {
            Text(AppBranding.Chat.deletedPlaceholder)
                .italic()
                .foregroundStyle(.secondary)
                .bubbleFill(own: row.isOwn)
        } else {
            BubbleContent(text: row.message.text ?? "",
                          quote: row.message.replyTo,
                          isQuoteDeleted: isQuoteDeleted,
                          own: row.isOwn,
                          hasMedia: row.message.hasAttachments,
                          mediaStandsAlone: row.message.attachments.allSatisfy(\.kind.isMedia),
                          onTapQuote: onTapQuote) {
                AttachmentGallery(message: row.message,
                                  loader: loader,
                                  own: row.isOwn,
                                  alignment: side,
                                  onTap: onTapAttachment,
                                  onOpenFile: onOpenFile)
            }
        }
    }

    private var timestamp: some View {
        Text(row.message.sentAt, format: .dateTime.hour().minute())
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    /// The client id keeps a bubble's identity across the optimistic -> stored swap; other senders' have only the server id.
    private var identifier: String {
        row.message.clientMessageId.map(AccessibilityIdentifiers.message(clientID:))
            ?? AccessibilityIdentifiers.message(id: row.message.id)
    }
}

#Preview {
    let now = Date.now
    let other = ChatMessage(id: "1",
                            groupId: "g",
                            senderUserId: "u-2",
                            senderName: "Marta",
                            text: "Anyone up for a game this week? The pitch by the canal is free on Thursday.",
                            sentAt: now)
    let own = ChatMessage(id: "2", groupId: "g", senderUserId: "me", senderName: "You", text: "Thursday works.", sentAt: now)
    let deleted = ChatMessage(id: "3", groupId: "g", senderUserId: "u-2", senderName: "Marta", sentAt: now, isDeleted: true)
    let reply = ChatMessage(id: "4",
                            groupId: "g",
                            senderUserId: "u-2",
                            senderName: "Marta",
                            text: "Great, see you there.",
                            sentAt: now,
                            replyTo: ReplyQuote(quoting: own, senderName: "You"))
    let loader = AppDependencies.makeMock().groups.attachments.loader
    ContentScreen {
        VStack(spacing: DesignTokens.Spacing.xs) {
            bubble(other, isOwn: false, isFirstInRun: true, isLastInRun: false, loader: loader)
            bubble(deleted, isOwn: false, isFirstInRun: false, isLastInRun: true, loader: loader)
            bubble(own, isOwn: true, isFirstInRun: true, isLastInRun: true, loader: loader)
            bubble(reply, isOwn: false, isFirstInRun: true, isLastInRun: true, loader: loader)
        }
        .padding()
    }
}

private func bubble(_ message: ChatMessage,
                    isOwn: Bool,
                    isFirstInRun: Bool,
                    isLastInRun: Bool,
                    loader: AttachmentLoader) -> MessageBubble {
    MessageBubble(row: MessageRow(message: message,
                                  isOwn: isOwn,
                                  senderName: message.senderName,
                                  isFirstInRun: isFirstInRun,
                                  isLastInRun: isLastInRun),
                  profile: UserProfileDestination(userId: message.senderUserId, displayName: message.senderName),
                  loader: loader)
}
