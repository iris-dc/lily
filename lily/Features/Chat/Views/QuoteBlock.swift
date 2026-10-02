import SwiftUI

/// The quoted original inside a reply's bubble: the bar, the sender's name and up to `quoteExcerptLines` of the
/// excerpt ("Photo" / "Video" / "File" for a media target without text), or "Message deleted" once this device knows
/// the original is gone. A plain fill like the bubble it sits in, never glass; one accessibility element
/// (`message-quote-<id>`) whose label is name and text, so a UI test finds the quote by what it says.
struct QuoteBlock: View {
    let quote: ReplyQuote
    let isDeleted: Bool
    let own: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            QuoteBar(color: barColor)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(quote.senderName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(barColor)
                Text(verbatim: text)
                    .font(.caption)
                    .italic(isDeleted)
                    .lineLimit(DesignTokens.Layout.quoteExcerptLines)
            }
        }
        // The bar is a shape and would grow to any height proposed; the two text lines decide the block's height.
        .fixedSize(horizontal: false, vertical: true)
        .padding(DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: .rect(cornerRadius: DesignTokens.Radius.quote))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityIdentifiers.messageQuote(id: quote.messageId))
    }

    private var text: String {
        isDeleted ? AppBranding.Chat.quotedDeleted : quote.displayText
    }

    /// White on the caller's accent bubble, the accent on everyone else's surface bubble.
    private var barColor: Color {
        own ? .white : .lilyAccent
    }

    private var fill: Color {
        (own ? Color.white : Color.lilyInk).opacity(DesignTokens.Opacity.quoteFill)
    }
}

/// The coloured bar at the leading edge of a quote, in a bubble and in the composer's preview.
struct QuoteBar: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: DesignTokens.Layout.quoteBarWidth / 2)
            .fill(color)
            .frame(width: DesignTokens.Layout.quoteBarWidth)
    }
}

/// Stacks a quote over the text that answers it so the bubble still hugs its content: each subview takes the width
/// its own words need within the width offered, and both are then laid out at the wider of the two. A `VStack` would
/// need `maxWidth: .infinity` on the quote to make it span the bubble, and that makes every reply as wide as the list
/// allows, a short "Yes!" under a short quote included.
struct QuoteStack: Layout {
    var spacing: CGFloat = DesignTokens.Spacing.xs

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = contentWidth(fitting: proposal, subviews)
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
        return CGSize(width: width, height: heights.reduce(0, +) + spacing * CGFloat(max(subviews.count - 1, 0)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for subview in subviews {
            let height = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
            subview.place(at: CGPoint(x: bounds.minX, y: y),
                          anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: height))
            y += height + spacing
        }
    }

    /// The widest subview once each is cut to the width offered: a flexible quote answers the offer itself, so its
    /// own words are measured unconstrained and capped; wrapped text answers less than the offer and keeps that.
    private func contentWidth(fitting proposal: ProposedViewSize, _ subviews: Subviews) -> CGFloat {
        let offered = ProposedViewSize(width: proposal.width, height: nil)
        let widths = subviews.map { min($0.sizeThatFits(.unspecified).width, $0.sizeThatFits(offered).width) }
        return widths.max() ?? 0
    }
}

#Preview {
    let quote = ReplyQuote(messageId: "m1", senderUserId: "u-2", senderName: "Marta", excerpt: "Can someone bring bibs?")
    ContentScreen {
        VStack(spacing: DesignTokens.Spacing.md) {
            QuoteBlock(quote: quote, isDeleted: false, own: false)
            QuoteBlock(quote: quote, isDeleted: true, own: true)
        }
        .padding()
    }
}
