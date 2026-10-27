import Foundation

/// The settings cards on Profile (the language and the currency) and the dropdown of choices they open.
nonisolated extension DesignTokens.Symbols {
    /// The currency card: the price glyph.
    static let currency = DesignTokens.Symbols.price
    /// The up-and-down chevrons at a settings card's value, as a picker's button carries.
    static let menuChevron = "chevron.up.chevron.down"
    /// The current choice in a settings dropdown.
    static let chosen = "checkmark"
}

nonisolated extension DesignTokens.Layout {
    /// How far a settings card's one-line value may shrink before it would wrap ("Systemowa (EUR)" next to "Waluta").
    static let menuLabelMinimumScale: CGFloat = 0.8
    /// A settings dropdown shows at most this many whole rows before it scrolls (fourteen currencies would reach past
    /// the screen), so it ends on a row's edge rather than mid-glyph.
    static let dropdownRows = 6
    /// A settings dropdown is as wide as its card, up to this, so it lines up with the card on a phone and stays a list
    /// on an iPad's readable column.
    static let dropdownMaxWidth: CGFloat = 400
}
