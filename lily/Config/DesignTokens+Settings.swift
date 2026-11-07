import Foundation

/// The settings cards on Profile (the language and the currency), the dropdown of choices they open, and the glyphs of
/// the Settings screen's rows.
nonisolated extension DesignTokens.Symbols {
    /// The currency card: the price glyph.
    static let currency = DesignTokens.Symbols.price
    /// The up-and-down chevrons at a settings card's value, as a picker's button carries.
    static let menuChevron = "chevron.up.chevron.down"
    /// The current choice in a settings dropdown.
    static let chosen = "checkmark"
    /// The Settings link row on the profile root.
    static let settings = "gearshape"
    /// The privacy policy link on the Settings screen.
    static let privacy = "lock.shield"
    /// The terms link on the Settings screen.
    static let terms = "doc.text"
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
