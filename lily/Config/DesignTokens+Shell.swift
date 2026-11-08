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
    /// The hidden capsule's content inset: the corner circle backs out by this and takes the capsule's own leading
    /// edge, flush with the large titles' margin on the iPhone (owner correction 2026-11-08; measured as the same
    /// 10 pt on the iPhone and iPad simulators, where the system's own capsule sits at 16 pt and 10 pt).
    static let profileCornerCapsuleInset: CGFloat = 10
}
