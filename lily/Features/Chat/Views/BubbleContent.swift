import SwiftUI

/// What a bubble holds on its fill: the quoted original above, the attachments between, the words below, each only
/// when there is one, stacked by `QuoteStack` so a short message still hugs its words. A message that is its pictures
/// and videos alone has no fill and no padding: the picture is the bubble, in the bubble's own corner radius; a file
/// card keeps the fill, since it is a card and not a picture. Plain fills, never glass: a chat scrolls dozens of these
/// at once.
struct BubbleContent<Media: View>: View {
    let text: String
    let quote: ReplyQuote?
    let isQuoteDeleted: Bool
    let own: Bool
    let hasMedia: Bool
    /// Whether the attachments alone may be the bubble (pictures and videos only; a file card needs the fill).
    var mediaStandsAlone = true
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
                if hasMedia {
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

    private var isMediaOnly: Bool { hasMedia && mediaStandsAlone && quote == nil && text.isEmpty }
}

extension BubbleContent where Media == EmptyView {
    /// Words and a quote only.
    init(text: String, quote: ReplyQuote?, isQuoteDeleted: Bool, own: Bool, onTapQuote: @escaping (ReplyQuote) -> Void) {
        self.init(text: text, quote: quote, isQuoteDeleted: isQuoteDeleted, own: own, hasMedia: false, onTapQuote: onTapQuote) {
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
            .containerRelativeFrame(.horizontal, alignment: side) { length, _ in
                length * DesignTokens.Layout.bubbleMaxWidthFraction
            }
            .frame(maxWidth: .infinity, alignment: side)
    }
}
