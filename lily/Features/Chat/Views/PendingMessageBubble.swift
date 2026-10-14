import SwiftUI

/// The caller's message before the backend confirmed it: faded with a spinner, or marked failed with the hint and a
/// Retry / Delete menu (attached only then; an empty menu would still open on a long press). Its attachments show from
/// their files on the device. A tap on a failed bubble or its glyph retries, never one on the row's empty space beside
/// it; its quote finds the original like any bubble's.
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

    /// The status glyph beside the content; the failed one is the button that retries.
    private var bubble: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
            status
            BubbleContent(text: message.text,
                          quote: message.replyTo,
                          isQuoteDeleted: message.replyTo.map(viewModel.quoteIsDeleted) ?? false,
                          own: true,
                          attachmentKinds: message.attachments.map(\.kind),
                          onTapQuote: onTapQuote) {
                DraftGallery(drafts: message.attachments, alignment: .trailing)
            }
            .opacity(message.hasFailed ? 1 : DesignTokens.Opacity.pendingMessage)
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
