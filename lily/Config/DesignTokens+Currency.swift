import Foundation

nonisolated extension DesignTokens.Symbols {
    /// The currency row on Profile.
    static let currency = "banknote"
    /// The up-and-down chevrons a menu picker's button carries; drawn by hand where the button's text is not the item's.
    static let menuChevron = "chevron.up.chevron.down"
}

nonisolated extension DesignTokens.Layout {
    /// How far a menu button's one-line text may shrink before it would wrap ("Systemowa (EUR)" next to "Waluta").
    static let menuLabelMinimumScale: CGFloat = 0.8
}
