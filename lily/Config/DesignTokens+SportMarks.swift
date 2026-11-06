import Foundation

/// The sport marks (a white glyph on the maroon-to-accent fill) and the map's selected cards.
nonisolated extension DesignTokens.Layout {
    /// The glyph's share of a sport mark's diameter.
    static let sportGlyphFraction: CGFloat = 0.46
    /// The soft accent glow under a sport mark, so the fill lifts off the glass around it.
    static let sportMarkGlowRadius: CGFloat = 4
    /// The hairline highlight around a sport mark's fill.
    static let sportMarkRimWidth: CGFloat = 0.5
    /// The small sport mark inside an `EventTypeChip`, scaled with the chip's text; no taller than the caption's line,
    /// so the chip stays the height of the price chip beside it.
    static let chipMarkSize: CGFloat = 16
    /// The map card's sport mark, the card's one bold element.
    static let mapCardMarkSize: CGFloat = 44
    /// The short how-full meter beside the spots on a map card.
    static let mapCardMeterWidth: CGFloat = 28
    /// A map card's title wraps to this many lines before it is cut.
    static let mapCardTitleLines = 2
    /// The fade over each edge of the card list while more waits beyond it.
    static let mapCardListFade: CGFloat = 56
    /// The share of a card that must be in view for the "+2 more" pill to count it as seen: a sliver, so a card
    /// taller than the list (accessibility sizes) still counts and the pill names only the whole cards after it.
    static let mapCardVisibleShare: Double = 0.01
    /// The card list's height before it is first measured: a zero-height scroll view never lays out its cards, so
    /// they would never report a height.
    static let mapCardListUnmeasuredHeight: CGFloat = 1
    /// Rounding the card list's scroll geometry may leave over without meaning there is more beyond an edge.
    static let mapCardEdgeSlack: CGFloat = 1
    /// The size the "+2 more" pill grows in from.
    static let mapMorePillEntryScale: CGFloat = 0.8
}

nonisolated extension DesignTokens.Opacity {
    /// The glow under a sport mark.
    static let sportMarkGlow: Double = 0.45
    /// The hairline highlight around a sport mark's fill.
    static let sportMarkRim: Double = 0.18
    /// How strongly maroon tints an `EventTypeChip`'s glass.
    static let sportGlassTint: Double = 0.55
    /// The ink wash under a map card's start capsule: a plain fill, since glass on the card's glass reads muddy.
    static let mapCardCapsuleFill: Double = 0.1
    /// The ink wash a card gets inside the many-events panel, where a second glass would muddy the first.
    static let mapPanelCardWash: Double = 0.07
}

nonisolated extension DesignTokens.Symbols {
    /// The "+2 more" pill under the map's card list.
    static let moreBelow = "chevron.down"
}
