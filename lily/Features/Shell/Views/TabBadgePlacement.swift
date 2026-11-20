import CoreGraphics

/// Where the overlay capsule sits, and when the bar's item views are trustworthy enough to host it
/// (`TabBarBadgeOverlay`); pure rules, so the fallback decision and the owner-tuned geometry are unit-tested.
enum TabBadgePlacement {
    /// The capsule's centre: the owner-tuned `badgeCenterOffset` from the top-right corner of the glyph the composite
    /// draws (`badgeGlyphPointSize`), anchored on the glyph view's centre — the bar centres the glyph in its item
    /// whichever image it holds, so the handoff from the composited label moves nothing. Pure geometry around the
    /// centre the caller measured, in whatever space it measured it (the overlay feeds each glyph's centre in its item's own coordinates, where its capsule mounts).
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

    /// How many parallel item trees the platter draws: every x-column must carry the same number of controls
    /// (the trees are identical copies), or nothing is trusted — a lone extra control would mount a capsule on a
    /// partial tree and pin the count to whichever copy happened to resolve.
    static func treeCount(itemColumns: [CGFloat], expectedTabs: Int) -> Int? {
        let columns = Set(itemColumns).sorted()
        guard columns.count == expectedTabs else { return nil }
        var counts: [CGFloat: Int] = [:]
        for column in itemColumns { counts[column, default: 0] += 1 }
        let sizes = Set(counts.values)
        guard sizes.count == 1, let size = sizes.first else { return nil }
        return size
    }

    /// Whether a pane is wide enough to be the expanded platter: the platter is the one pane that scales with the
    /// bar (about three quarters of it on every device), while the minimized circle (48 pt), the ~100 pt tab-switch
    /// transient and a pre-layout zero-width pane all sit under half — and an unlaid-out bar trusts nothing.
    static func isPlatter(paneWidth: CGFloat, barWidth: CGFloat) -> Bool {
        barWidth > 0 && paneWidth >= barWidth * AppConfig.Shell.tabBarPlatterMinimumFraction
    }
}
