import SwiftUI

/// The caller's message before the backend confirmed it: faded with a spinner, or marked failed with the hint and a
/// Retry / Delete menu. Its pictures, videos and files show from their files on the device. Tapping a failed bubble
/// retries; tapping its quote finds the original like any bubble's.
struct PendingMessageBubble: View {
    let message: PendingMessage
    let viewModel: ChatViewModel
    var onTapQuote: (ReplyQuote) -> Void = { _ in }

    private typealias Copy = AppBranding.Chat

    var body: some View {
        VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
                status
                BubbleContent(text: message.text,
                              quote: message.replyTo,
                              isQuoteDeleted: message.replyTo.map(viewModel.quoteIsDeleted) ?? false,
                              own: true,
                              hasMedia: message.hasAttachments,
                              mediaStandsAlone: message.attachments.allSatisfy(\.kind.isMedia),
                              onTapQuote: onTapQuote) {
                    DraftGallery(drafts: message.attachments, alignment: .trailing)
                }
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
