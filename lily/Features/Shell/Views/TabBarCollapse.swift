import CoreGraphics

/// The iOS 26 floating bar's state, told from its panes (one per settled state, swapped by visibility). The small
/// panes are absolute sizes on every device — the minimized circle 48 pt, the mid-churn transient about 100 pt —
/// while the expanded platter scales with the bar (about three quarters of it), so the circle is told by an absolute
/// bound and the platter by a fraction (`AppConfig.Shell`). A settled state shows one endpoint alone; a morph shows
/// both at once — the circle joins the platter on screen the moment a collapse or an expand starts, about 0.7 s
/// before the leaving pane hides, which is what lets the capsule fade over the morph instead of after it. A pane
/// before its first layout reports zero width: no laid-out visible pane is no signal, and the answer is expanded —
/// a wrong "minimized" would hide the badge with no later KVO event to correct it.
enum TabBarCollapse {
    enum Phase: Equatable {
        case expanded, minimized, morphing
    }

    /// `morphing` iff both endpoints show: the platter (at least `tabBarPlatterMinimumFraction` of the bar) and the
    /// circle (at most the absolute `tabBarCircleMaxWidth` — a width-relative circle bound crossed the ~100 pt
    /// tab-switch transient on 400 pt-class bars and read every tab switch as a morph). One endpoint alone is its
    /// settled state; any other shape, and every fail-safe, answers expanded.
    static func phase(visiblePaneWidths: [CGFloat], barWidth: CGFloat) -> Phase {
        guard barWidth > 0 else { return .expanded }
        let laidOut = visiblePaneWidths.filter { $0 > 0 }
        guard let widest = laidOut.max() else { return .expanded }
        let showsPlatter = widest >= barWidth * AppConfig.Shell.tabBarPlatterMinimumFraction
        let showsCircle = laidOut.contains { $0 <= AppConfig.Shell.tabBarCircleMaxWidth }
        if showsPlatter { return showsCircle ? .morphing : .expanded }
        return showsCircle ? .minimized : .expanded
    }

    /// The settled phase carried across reads: a settled read replaces it, a morph keeps it, and the first read has
    /// none to keep — a mid-morph first read seeds minimized, so the capsule errs visible (`fadesOut`) and the next
    /// settle corrects it.
    static func settle(current: Phase, previous: Phase?) -> Phase {
        current == .morphing ? (previous ?? .minimized) : current
    }

    /// Whether the capsule is faded out: out while minimized, shown while expanded, and mid-morph the opposite of
    /// the last settled state — a starting collapse fades out with the morph, a starting expand fades back in, and
    /// a morph abandoned midway corrects itself at the next settle.
    static func fadesOut(phase: Phase, settled: Phase) -> Bool {
        switch phase {
        case .expanded: false
        case .minimized: true
        case .morphing: settled == .expanded
        }
    }
}

/// Where the overlay capsule sits, and when the bar's item views are trustworthy enough to host it
/// (`TabBarBadgeOverlay`); pure rules, so the fallback decision and the owner-tuned geometry are unit-tested.
enum TabBadgePlacement {
    /// The capsule's centre: the owner-tuned `badgeCenterOffset` from the top-right corner of the glyph the composite
    /// draws (`badgeGlyphPointSize`), anchored on the glyph view's centre — the bar centres the glyph in its item
    /// whichever image it holds, so the handoff from the composited label moves nothing.
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
}
