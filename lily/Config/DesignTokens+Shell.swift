import UIKit

nonisolated extension DesignTokens {
    /// The tab bar's glyphs. The iOS 26 tab bar draws `Tab(_:systemImage:)` symbols at its own heavy weight and fills
    /// most of them in both states, ignoring `symbolVariants` and `fontWeight`; a `UIImage` built with a symbol
    /// configuration keeps its weight, is never auto-filled and takes the bar's point size, so `MainTabView` builds its
    /// labels from one at this weight.
    enum TabBar {
        static let symbolWeight: UIImage.SymbolWeight = .light
    }
}

nonisolated extension DesignTokens.Layout {
    /// The corner profile button's circle (initials or the person glyph). The toolbar item's own capsule is hidden, so
    /// the circle is the one surface — no glass on glass.
    static let profileCornerSize: CGFloat = 36
}
