import Foundation

nonisolated extension DesignTokens.Symbols {
    /// The currency row on Profile: the price glyph.
    static let currency = DesignTokens.Symbols.price
    /// The up-and-down chevrons a picker's button carries; drawn by hand where the button's text is not the item's.
    static let menuChevron = "chevron.up.chevron.down"
    /// The current choice in a settings dropdown.
    static let chosen = "checkmark"
}

nonisolated extension DesignTokens.Layout {
    /// How far a settings card's one-line value may shrink before it would wrap ("Systemowa (EUR)" next to "Waluta").
    static let menuLabelMinimumScale: CGFloat = 0.8
    /// A settings dropdown shows at most this many whole rows (`controlHeight` each; the hairlines between them cut the
    /// last by under 2 pt) before it scrolls, so it ends on a row's edge rather than mid-glyph; fourteen currencies would
    /// reach past the screen.
    static let dropdownMaxHeight: CGFloat = 6 * controlHeight
    /// A settings dropdown is as wide as its card, up to this, so it lines up with the card on a phone and stays a list
    /// on an iPad's readable column.
    static let dropdownMaxWidth: CGFloat = 400
}
