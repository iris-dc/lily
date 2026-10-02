import SwiftUI

/// What the composer shows above the field while the draft answers a message: the accent bar, "Replying to Marta", one
/// line of the quoted text and an X that drops the reply. A container for the UI tests (`chat-reply-preview`), so the
/// identifier is not stamped on its children and the X keeps its own.
struct ReplyPreviewBar: View {
    let quote: ReplyQuote
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            QuoteBar(color: .lilyAccent)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(AppBranding.Chat.replyingTo(quote.senderName))
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(Color.lilyAccent)
                Text(verbatim: quote.displayText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            cancelButton
        }
        // The bar is a shape and would take every point of height the composer's inset offers; the text decides.
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .glassEffect(.regular, in: .rect(cornerRadius: DesignTokens.Radius.md))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.chatReplyPreview)
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Image(systemName: DesignTokens.Symbols.dismiss)
                .foregroundStyle(.secondary)
                .frame(minWidth: DesignTokens.Layout.controlHeight)
                .tappableLabel()
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(AppBranding.Chat.cancelReply)
        .accessibilityIdentifier(AccessibilityIdentifiers.chatReplyCancel)
    }
}

#Preview {
    let quote = ReplyQuote(messageId: "m1",
                           senderUserId: "u-2",
                           senderName: "Marta",
                           excerpt: "Anyone up for a game this week? The pitch by the canal is free on Thursday.")
    ContentScreen {
        VStack {
            Spacer()
            ReplyPreviewBar(quote: quote) {}
                .padding()
        }
    }
}
