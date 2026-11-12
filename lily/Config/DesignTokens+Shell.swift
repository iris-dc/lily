import UIKit

nonisolated extension DesignTokens {
    /// The tab bar's glyphs. The iOS 26 tab bar draws `Tab(_:systemImage:)` symbols at its own heavy weight and fills
    /// most of them in both states, ignoring `symbolVariants` and `fontWeight`; a `UIImage` built with a symbol
    /// configuration keeps its weight, is never auto-filled and takes the bar's point size, so `MainTabView` builds its
    /// labels from one at this weight.
    enum TabBar {
        static let symbolWeight: UIImage.SymbolWeight = .light
        /// The Chats tab's unread count, drawn into the glyph image (`TabBadgeRenderer`): the bar never moves its own
        /// badge (`badgePositionAdjustment` probed at zero effect), so the count sits where the owner wants it — its
        /// centre this far from the glyph's top-right corner (x into the glyph, y below its top; the system badge sat
        /// at about (+13, +3) on the same glyph), clearly further left and down.
        static let badgeCenterOffset = CGPoint(x: -1, y: 9)
        /// The composite draws its own glyph (the bar re-renders template symbols at its own size but draws a bitmap
        /// as-is), so the symbol is built at the size the bar gives the template neighbours, measured against them.
        static let badgeGlyphPointSize: CGFloat = 23
        /// The capsule matches the system badge (~19.7 pt measured on the iOS 26 bar), the count in white SF Rounded;
        /// a single digit reads as a circle (the capsule is never narrower than it is tall).
        static let badgeHeight: CGFloat = 20
        static let badgeFontSize: CGFloat = 13
        static let badgeHorizontalPadding: CGFloat = 5
        /// Counts above this read "99+", like the system badge.
        static let badgeCountCap = 99
        static let badgeTextColor: UIColor = .white
        /// The composite draws as `.alwaysOriginal` (a template would tint the badge with the glyph), so the glyph's
        /// colour is drawn in: this unselected, matching the bar's own template tint, the accent while selected.
        static let unselectedGlyphColor: UIColor = .white
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
