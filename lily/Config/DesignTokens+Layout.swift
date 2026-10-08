import Foundation

nonisolated extension DesignTokens.Layout {
    /// A regular width at least this wide is `LayoutMode.wide`: room for Explore's content column and a map side by side.
    static let wideMinWidth: CGFloat = 1000
    /// Widest a column of reading text and controls gets on a wide screen; narrower screens are unaffected.
    static let readableWidth: CGFloat = 720
    /// Bounds of one card in an adaptive grid on a regular width; compact widths keep a single column.
    static let cardMinWidth: CGFloat = 340
    static let cardMaxWidth: CGFloat = 520
    /// Narrowest a group tile gets in the regular-width grid that replaces the carousel.
    static let tileMinWidth: CGFloat = 250
    /// Tiles the regular-width group grid shows before "See all".
    static let regularTileCount = 8
    /// Share of a wide Explore the content column takes; the map pane takes the rest.
    static let exploreContentFraction: CGFloat = 0.55
    /// Widest the intro's framed miniature gets beside its caption on a regular width.
    static let introScreenWideWidth: CGFloat = 360
    /// Widest the landing's two capsules get on a regular width.
    static let landingButtonMaxWidth: CGFloat = 440
    /// Widest an intro slide's composition (the miniature beside its caption) gets on a regular width.
    static let introCompositionMaxWidth: CGFloat = 960
    /// Tallest the wide miniature gets relative to its width: a phone's proportions, not the whole page's height.
    static let introScreenWideAspect: CGFloat = 2.1
    /// How far a headline line may shrink to stay on one line (the SE's 375 pt needs it).
    static let headlineMinimumScale: CGFloat = 0.8
}

nonisolated extension DesignTokens.Opacity {
    /// The accent wash behind the conversation row a split view's detail shows.
    static let selectedRow: Double = 0.18
}

nonisolated extension DesignTokens.Layout {
    /// The conversation list column of the Chats split view: a row's avatar, two lines of text and the dot fit at the
    /// minimum; the maximum keeps the room the wider column on an iPad in portrait.
    static let chatsSidebarMinWidth: CGFloat = 300
    static let chatsSidebarIdealWidth: CGFloat = 360
    static let chatsSidebarMaxWidth: CGFloat = 420
}
