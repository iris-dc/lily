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

    /// What a failed re-resolve does next (`TabBarBadgeOverlay`): inside the armed grace a hosted failure retries
    /// with the label kept plain (the device rebuilds the selected item non-atomically, so the first re-resolves
    /// meet half-built trees); a spent grace hands off once, saying so; an unarmed failure is an ordinary
    /// stand-down and hands off at once.
    enum HandoffStep {
        case graceRetry
        case handOffAfterGrace
        case handOff
    }

    /// Pure over the caller's clock, so the grace rule is unit-tested.
    static func handoffStep(isHosting: Bool,
                            graceArmed: Bool,
                            deadline: CFTimeInterval,
                            now: CFTimeInterval) -> HandoffStep {
        if isHosting && graceArmed && now < deadline { return .graceRetry }
        return graceArmed ? .handOffAfterGrace : .handOff
    }

    /// The deadline a churn arms, or nothing: only a HOSTED churn arms the grace (an ordinary stand-down hands
    /// off at once), and only once per episode — a churn during the grace never extends it, or a churn storm
    /// over unresolvable trees would keep the count off screen indefinitely.
    static func armedGraceDeadline(isHosting: Bool, graceArmed: Bool, now: CFTimeInterval) -> CFTimeInterval? {
        guard isHosting, !graceArmed else { return nil }
        return now + AppConfig.Shell.tabBarHandoffGraceSeconds
    }

    /// Whether resolved hosts still match the drawn trees' glyphs, by count AND identity; an empty current
    /// shape is mid-churn noise, not staleness (left to the dead-host and failure paths).
    static func hostsAreStale(current: [ObjectIdentifier], resolved: [ObjectIdentifier], hostCount: Int) -> Bool {
        guard !current.isEmpty else { return false }
        if current.count != hostCount { return true }
        return Set(current) != Set(resolved)
    }
}
