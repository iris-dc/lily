import SwiftUI

/// What a bubble holds on its fill: the quoted original above, the attachments between, the words below, each only
/// when there is one, stacked by `QuoteStack` so a short message still hugs its words. `BubbleFill.standsAlone` decides
/// from the attachments' kinds, the words and the quote whether the attachments are the bubble themselves (pictures and
/// videos alone: no fill, no padding, the bubble's own corner radius) or sit on the fill, as a file card does. The
/// stored and the unsent bubble both draw through it. Plain fills, never glass: a chat scrolls dozens of these at once.
struct BubbleContent<Media: View>: View {
    let text: String
    let quote: ReplyQuote?
    let isQuoteDeleted: Bool
    let own: Bool
    /// The kinds of the message's attachments in their order; `media` draws them all, tiles and cards alike.
    let attachmentKinds: [AttachmentKind]
    let onTapQuote: (ReplyQuote) -> Void
    @ViewBuilder let media: () -> Media

    var body: some View {
        if isMediaOnly {
            media()
                .clipShape(.rect(cornerRadius: DesignTokens.Radius.bubble))
        } else {
            QuoteStack {
                if let quote {
                    QuoteBlock(quote: quote, isDeleted: isQuoteDeleted, own: own)
                        .onTapGesture { onTapQuote(quote) }
                }
                if hasAttachments {
                    media()
                        .clipShape(.rect(cornerRadius: DesignTokens.Radius.quote))
                }
                if !text.isEmpty {
                    Text(verbatim: text)
                }
            }
            .bubbleFill(own: own)
        }
    }

    private var hasAttachments: Bool { !attachmentKinds.isEmpty }

    private var isMediaOnly: Bool {
        BubbleFill.standsAlone(kinds: attachmentKinds, hasText: !text.isEmpty, hasQuote: quote != nil)
    }
}

extension BubbleContent where Media == EmptyView {
    /// Words and a quote only.
    init(text: String, quote: ReplyQuote?, isQuoteDeleted: Bool, own: Bool, onTapQuote: @escaping (ReplyQuote) -> Void) {
        self.init(text: text,
                  quote: quote,
                  isQuoteDeleted: isQuoteDeleted,
                  own: own,
                  attachmentKinds: [],
                  onTapQuote: onTapQuote) {
            EmptyView()
        }
    }
}

extension View {
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
            .transcriptFraction(DesignTokens.Layout.bubbleMaxWidthFraction, alignment: side)
            .frame(maxWidth: .infinity, alignment: side)
    }
}
