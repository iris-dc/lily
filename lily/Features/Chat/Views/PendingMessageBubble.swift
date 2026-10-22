import SwiftUI

/// The caller's message before the backend confirmed it: drawn as the stored bubble will be, so the confirmation
/// changes nothing a reader sees while the arrival still fades it in, or marked failed with the glyph, the hint and a
/// Retry / Delete menu (attached only then; an empty menu would still open on a long press). Its attachments show from
/// their files on the device. A tap on a failed bubble or its glyph retries, never one on the row's empty space beside
/// it; its quote finds the original like any bubble's. While it is sending it keeps the line the stored bubble's time
/// will take, empty, so the confirmation changes no height and the transcript's slide runs on through it.
struct PendingMessageBubble: View {
    let message: PendingMessage
    let viewModel: ChatViewModel
    var onTapQuote: (ReplyQuote) -> Void = { _ in }

    private typealias Copy = AppBranding.Chat

    var body: some View {
        let row = VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
            bubble
            if message.hasFailed {
                Text(Copy.failedHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                MessageTimestamp(date: message.sentAt)
                    .hidden()
            }
        }
        .bubbleRow(side: .trailing)
        .accessibilityIdentifier(AccessibilityIdentifiers.message(clientID: message.clientMessageID))
        if message.hasFailed {
            row.contextMenu { failedMenu }
        } else {
            row
        }
    }

    /// The failed glyph beside the content is the button that retries; a bubble on its way shows nothing beside it.
    private var bubble: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
            if message.hasFailed {
                Image(systemName: DesignTokens.Symbols.failed)
                    .foregroundStyle(Color.lilyAccent)
                    .accessibilityLabel(Copy.failedHint)
            }
            BubbleContent(text: message.text,
                          quote: message.replyTo,
                          isQuoteDeleted: message.replyTo.map(viewModel.quoteIsDeleted) ?? false,
                          own: true,
                          attachmentKinds: message.attachments.map(\.kind),
                          onTapQuote: onTapQuote) {
                DraftGallery(drafts: message.attachments, alignment: .trailing)
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            if message.hasFailed { Task { await viewModel.retry(message) } }
        }
        .accessibilityAddTraits(message.hasFailed ? .isButton : [])
    }

    @ViewBuilder private var failedMenu: some View {
        Button(Copy.retry, systemImage: DesignTokens.Symbols.send) { Task { await viewModel.retry(message) } }
        Button(Copy.deleteMessage, systemImage: DesignTokens.Symbols.delete, role: .destructive) {
            viewModel.discard(message)
        }
    }
}
