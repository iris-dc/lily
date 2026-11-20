import CoreGraphics

/// Where the overlay capsule sits, and when the bar's item views are trustworthy enough to host it
/// (`TabBarBadgeOverlay`); pure rules, so the fallback decision and the owner-tuned geometry are unit-tested.
enum TabBadgePlacement {
    /// The capsule's centre: the owner-tuned `badgeCenterOffset` from the top-right corner of the glyph the composite
    /// draws (`badgeGlyphPointSize`), anchored on the glyph view's centre — the bar centres the glyph in its item
    /// whichever image it holds, so the handoff from the composited label moves nothing. Pure geometry around the
    /// centre the caller measured, in whatever space it measured it (the overlay converts into platter coordinates).
    static func capsuleCenter(glyphCenter: CGPoint, glyphSize: CGSize) -> CGPoint {
        let offset = DesignTokens.TabBar.badgeCenterOffset
        return CGPoint(x: glyphCenter.x + glyphSize.width / 2 + offset.x,
                       y: glyphCenter.y - glyphSize.height / 2 + offset.y)
    }

    /// The Chats item's x-column among the platter's item views, or nothing when the shape is not the expected one
    /// (the overlay then leaves the count composited into the glyph). The platter holds two parallel item trees with
    /// identical frames, so items are counted as distinct x-columns, not as views; exactly one column per tab, in bar
    /// order, is the only shape trusted.
    static func chatsColumn(itemColumns: [CGFloat], chatIndex: Int, expectedTabs: Int) -> CGFloat? {
        let columns = Set(itemColumns).sorted()
        guard columns.count == expectedTabs, (0..<expectedTabs).contains(chatIndex) else { return nil }
        return columns[chatIndex]
    }

    /// The bar's two state panes, for the twin rule's memory of which unhid last.
    enum Pane {
        case platter, circle
    }

    /// Which badge twin draws, told from the two state panes alone — a rule that exists on any bar hierarchy,
    /// where transient detection does not (the device mounts its selection glass outside the bar's subviews).
    /// The bar-level twin draws wherever the platter shows settled (the circle hidden, or absent — `nil` reads
    /// as hidden — covering rest and every tab switch) or is arriving (both panes visible with the platter unhid
    /// last: the expand reads full from its first frame, the owner's ask over riding in); the platter capsule
    /// rides only while the circle unhid last — a collapse, the one morph the badge must move and fade with —
    /// and an unknown direction errs to the ride.
    static func twinShows(platterHidden: Bool, circleHidden: Bool?, lastUnhidden: Pane?) -> Bool {
        guard !platterHidden else { return false }
        guard circleHidden == false else { return true }
        return lastUnhidden == .platter
    }

    /// Who draws the badge: the twin, the riding capsule, or — not hosting — neither, because the stand-down's
    /// sequenced hand-back owns the carriers and flipping them early would show a shaved capsule for a frame.
    /// Hosting decided, `twinShows` picks the twin or the ride.
    enum Drawer {
        case twin, ride, standDown
    }

    static func badgeDrawer(hosting: Bool, platterHidden: Bool, circleHidden: Bool?, lastUnhidden: Pane?) -> Drawer {
        guard hosting else { return .standDown }
        let twin = twinShows(platterHidden: platterHidden, circleHidden: circleHidden, lastUnhidden: lastUnhidden)
        return twin ? .twin : .ride
    }

    /// Whether a pane is wide enough to be the expanded platter: the platter is the one pane that scales with the
    /// bar (about three quarters of it on every device), while the minimized circle (48 pt), the ~100 pt tab-switch
    /// transient and a pre-layout zero-width pane all sit under half — and an unlaid-out bar trusts nothing.
    static func isPlatter(paneWidth: CGFloat, barWidth: CGFloat) -> Bool {
        barWidth > 0 && paneWidth >= barWidth * AppConfig.Shell.tabBarPlatterMinimumFraction
    }
}
