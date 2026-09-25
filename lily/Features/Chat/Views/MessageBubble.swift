import SwiftUI

/// One member's message as a bubble: the caller's in the accent, trailing; everyone else's on the surface colour,
/// leading, with the sender's avatar and current name on the first bubble of a run and the time under the last.
/// Plain fills, never glass: a chat scrolls dozens of these at once.
struct MessageBubble: View {
    let row: MessageRow

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
        .accessibilityIdentifier(identifier)
    }

    private var side: Alignment { row.isOwn ? .trailing : .leading }

    /// Only the first bubble of a run shows the avatar; the rest keep its column so the run lines up.
    @ViewBuilder private var avatarColumn: some View {
        if row.isFirstInRun {
            AvatarCircle(initials: row.senderName.initials,
                         size: DesignTokens.Layout.avatarSmall,
                         tint: .lilySecondary,
                         tintOpacity: DesignTokens.Opacity.secondaryGlassTint)
        } else {
            Color.clear.frame(width: DesignTokens.Layout.avatarSmall, height: 0)
        }
    }

    private var senderName: some View {
        Text(row.senderName)
            .font(LilyTheme.Fonts.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    @ViewBuilder private var bubble: some View {
        if row.message.isDeleted {
            Text(AppBranding.Chat.deletedPlaceholder)
                .italic()
                .foregroundStyle(.secondary)
                .bubbleFill(own: row.isOwn)
        } else {
            Text(verbatim: row.message.text ?? "")
                .bubbleFill(own: row.isOwn)
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

/// The caller's message before the backend confirmed it: faded with a spinner, or marked failed with the hint and a
/// Retry / Delete menu. Tapping a failed bubble retries.
struct PendingMessageBubble: View {
    let message: PendingMessage
    let viewModel: ChatViewModel

    private typealias Copy = AppBranding.Chat

    var body: some View {
        VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
                status
                Text(verbatim: message.text)
                    .bubbleFill(own: true)
                    .opacity(message.hasFailed ? 1 : DesignTokens.Opacity.pendingMessage)
            }
            if message.hasFailed {
                Text(Copy.failedHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .bubbleRow(side: .trailing)
        .contentShape(.rect)
        .onTapGesture {
            if message.hasFailed { Task { await viewModel.retry(message) } }
        }
        .accessibilityAddTraits(message.hasFailed ? .isButton : [])
        .contextMenu {
            if message.hasFailed {
                Button(Copy.retry, systemImage: DesignTokens.Symbols.send) { Task { await viewModel.retry(message) } }
                Button(Copy.deleteMessage, systemImage: DesignTokens.Symbols.delete, role: .destructive) {
                    viewModel.discard(message)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.message(clientID: message.clientMessageID))
    }

    @ViewBuilder private var status: some View {
        if message.hasFailed {
            Image(systemName: DesignTokens.Symbols.failed)
                .foregroundStyle(Color.lilyAccent)
                .accessibilityLabel(Copy.failedHint)
        } else {
            ProgressView()
                .controlSize(.small)
                .accessibilityHidden(true)
        }
    }
}

private extension View {
    /// Body text on a plain rounded fill: accent with white text for the caller, surface with ink for the others.
    func bubbleFill(own: Bool) -> some View {
        font(.body)
            .foregroundStyle(own ? Color.white : Color.lilyInk)
            .padding(.horizontal, DesignTokens.Layout.bubbleHorizontalPadding)
            .padding(.vertical, DesignTokens.Layout.bubbleVerticalPadding)
            .background(own ? Color.lilyAccent : Color.lilySurface, in: .rect(cornerRadius: DesignTokens.Radius.bubble))
    }

    /// A row of the transcript: the content may take `bubbleMaxWidthFraction` of the list and hugs its side.
    func bubbleRow(side: Alignment) -> some View {
        frame(maxWidth: .infinity, alignment: side)
            .containerRelativeFrame(.horizontal, alignment: side) { length, _ in
                length * DesignTokens.Layout.bubbleMaxWidthFraction
            }
            .frame(maxWidth: .infinity, alignment: side)
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
    ContentScreen {
        VStack(spacing: DesignTokens.Spacing.xs) {
            MessageBubble(row: row(other, isOwn: false, isFirstInRun: true, isLastInRun: false))
            MessageBubble(row: row(deleted, isOwn: false, isFirstInRun: false, isLastInRun: true))
            MessageBubble(row: row(own, isOwn: true, isFirstInRun: true, isLastInRun: true))
        }
        .padding()
    }
}

private func row(_ message: ChatMessage, isOwn: Bool, isFirstInRun: Bool, isLastInRun: Bool) -> MessageRow {
    MessageRow(message: message,
               isOwn: isOwn,
               senderName: message.senderName,
               isFirstInRun: isFirstInRun,
               isLastInRun: isLastInRun)
}
