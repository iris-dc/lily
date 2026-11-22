import UIKit

/// The find, mount and retry half of the overlay, split from the main file under the length limit; the stored
/// state lives in `TabBarBadgeOverlay.swift` and is internal for this extension.
extension TabBarBadgeOverlay.OverlayView {
    /// The Chats items' glyphs: inside the expanded platter — the one pane spanning most of the bar
    /// (`TabBadgePlacement.isPlatter`), so the minimized circle, the ~100 pt tab-switch transient and a pre-layout
    /// zero-width pane never host — where the item views are the controls in bar order, two parallel trees at
    /// identical frames (`SelectedContentView` and `ContentView`). Whole trees only: the column pick and the
    /// uniform-multiplicity rule are `TabBadgePlacement`'s, and every Chats item must have its glyph — a partial
    /// mount would pin the count to whichever tree happened to resolve. A success replaces the previous hosts
    /// only after the new capsules are mounted, so the swap never blanks.
    func resolveGlyphs(in bar: UITabBar) {
        platter = bar.subviews
            .filter { TabBadgePlacement.isPlatter(paneWidth: $0.bounds.width, barWidth: bar.bounds.width) }
            .max(by: { $0.bounds.width < $1.bounds.width })
        guard let platter else {
            resolveFailed(reason: "no expanded platter")
            return
        }
        let glyphs = Self.chatsGlyphs(inPlatter: platter)
        diagnose("resolved \(glyphs.count) item glyphs")
        guard !glyphs.isEmpty else {
            resolveFailed(reason: "Chats glyphs not resolved")
            return
        }
        let previous = hosts
        hosts = glyphs.map { glyph in
            observeLayout(of: glyph)
            return BadgeHost(glyph: glyph) { [weak self] in self?.capsuleWasEvicted() }
        }
        remount()
        for old in previous { old.capsule.onDetach = nil }
        unmountCapsules(previous.map(\.capsule))
        sweepLeaving()
        registerCapsules()
        graceDeadline = 0
        graceArmed = false
        freshMount = true
        refreshCapsules()
        // The first reposition judges the fit; a capsule the platter's clip would cut has stood down already.
        guard !capsuleUnfit else { return }
        host(true)
    }

    /// The mounted capsules are retired, not stripped: they leave in the composite's commit (`host(false)`'s
    /// transaction completion, or the next successful mount's sweep), so the count never blanks while the search
    /// runs again. A failure right after a hosted hierarchy churned (an eviction, a glyph death, a dead-host
    /// pane or item churn) retries through a bounded
    /// grace first (`AppConfig.Shell.tabBarHandoffGraceSeconds`, a deadline — the rebuild's own churns re-attach
    /// faster than the retry timer and would burn a counted grace in a millisecond): the device rebuilds the selected item
    /// non-atomically, so the first re-resolve can meet half-built trees, and a composite hand-off would visibly
    /// crossfade through the rebuilding item — during the grace the badge is deliberately absent inside an item
    /// that is itself mid-rebuild, the one planned blank beside a fresh mount's fit trip. Ordinary stand-downs
    /// (no bar, cold start) hand off at once. The decision is the pinned pure rule (`TabBadgePlacement.handoffStep`).
    private func resolveFailed(reason: String) {
        switch TabBadgePlacement.handoffStep(isHosting: isHosting,
                                             graceArmed: graceArmed,
                                             deadline: graceDeadline,
                                             now: CACurrentMediaTime()) {
        case .graceRetry:
            diagnose("grace-retry")
            removeHosts()
        case .handOffAfterGrace:
            graceArmed = false
            diagnose("handed off after grace")
            retireHosts()
            host(false)
        case .handOff:
            retireHosts()
            host(false)
        }
        scheduleRetry(reason: reason)
    }

    /// Every item tree's Chats glyph, one per parallel tree, in subview order; `[]` for any shape that is not
    /// whole DRAWABLE trees. Adoption uses the condemnation standard (`isDrawable`): a stale hidden tree beside
    /// the live ones is simply ignored, and a shape where only stale trees parse as whole fails the resolve onto
    /// the grace and hand-off path — adopting it would spin glyph-death churns against it forever.
    static func chatsGlyphs(inPlatter platter: UIView) -> [UIImageView] {
        let controls = descendants(of: UIControl.self, in: platter)
            .filter { $0.bounds.width > 0 && isDrawable($0, upTo: platter) }
        let columns = controls.map { $0.frame.minX.rounded() }
        guard let chatIndex = AppTab.shown.firstIndex(of: .chat),
              let column = TabBadgePlacement.chatsColumn(itemColumns: columns,
                                                         chatIndex: chatIndex,
                                                         expectedTabs: AppTab.shown.count),
              let trees = TabBadgePlacement.treeCount(itemColumns: columns,
                                                      expectedTabs: AppTab.shown.count) else { return [] }
        let glyphs = controls
            .filter { $0.frame.minX.rounded() == column }
            .compactMap { descendants(of: UIImageView.self, in: $0).first }
            .filter { isDrawable($0, upTo: platter) }
        return glyphs.count == trees ? glyphs : []
    }

    /// One pass per turn: a layout burst fires every glyph observation at once, and each pass walks every
    /// host anyway.
    func scheduleReposition() {
        guard !repositionPending else { return }
        repositionPending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.repositionPending = false
            self.reposition()
        }
    }

    // MARK: - The hosts' lifecycle

    /// Failure paths: the capsules stay mounted (silenced) until the composite's commit sweeps them, and the
    /// emptied hosts let the retry's re-attach guard pass.
    func retireHosts() {
        for badgeHost in hosts { badgeHost.capsule.onDetach = nil }
        leavingCapsules += hosts.map(\.capsule)
        hosts = []
        registerCapsules()
    }

    /// Teardown: the overlay leaves the window, so everything goes now.
    func removeHosts() {
        for badgeHost in hosts { badgeHost.capsule.onDetach = nil }
        unmountCapsules(hosts.map(\.capsule))
        hosts = []
        sweepLeaving()
        registerCapsules()
    }

    func sweepLeaving() {
        unmountCapsules(leavingCapsules)
        leavingCapsules = []
    }

    func unmountCapsules(_ capsules: [TabBadgeCapsuleView]) {
        for capsule in capsules { capsule.removeFromSuperview() }
    }

    /// Mounts every capsule directly above its tree's glyph — the spot the lens copies.
    func remount() {
        for badgeHost in hosts {
            guard let glyph = badgeHost.glyph, let item = glyph.superview else { continue }
            if badgeHost.capsule.superview !== item { item.insertSubview(badgeHost.capsule, aboveSubview: glyph) }
        }
    }

    /// The diagnostics tail samples the live capsules even around a hand-off, so the registration follows every
    /// hosts change; debug builds only.
    func registerCapsules() {
        #if DEBUG
        BadgePaneDiagnostics.shared.register(capsules: hosts.map(\.capsule))
        #endif
    }

    /// Both layout key paths of a glyph coalesce into one reposition pass per turn (`scheduleReposition`).
    private func observeLayout(of glyph: UIImageView) {
        observations.append(glyph.layer.observe(\.bounds) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.scheduleReposition() }
        })
        observations.append(glyph.layer.observe(\.position) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.scheduleReposition() }
        })
    }

    /// Debug-only: mirrors the event through the facade (an attached console and `SpyLogger` see it) and records
    /// it with a 2 s bar-shape tail to the pullable file (`BadgePaneDiagnostics`); release builds evaluate nothing.
    func diagnose(_ event: @autoclosure () -> String) {
        #if DEBUG
        let message = event()
        logger?.debug(.ui, "Tab badge: \(message)")
        BadgePaneDiagnostics.shared.note(message, bar: bar, capsules: hosts.map(\.capsule))
        #endif
    }

    /// The bar joins the window a few frames after this view does (SwiftUI adds its UIKit backing separately),
    /// so a failed find retries on short deferrals; the budget ends the search, so it never becomes polling.
    /// A search that spends it says so once: the fallback composite is correct but silent, and without the line
    /// a lost bar would never be noticed.
    func scheduleRetry(reason: String) {
        guard window != nil else { return }
        guard findBudget > 0 else {
            if graceArmed {
                // The grace relies on a future retry for its hand-off; with the budget spent none is coming,
                // so it goes now — never a wedged hosting-true with no capsules and no timer. The stood-down
                // warning is for a silently lost bar, not for this deliberate hand-off.
                graceArmed = false
                diagnose("handed off after grace")
                retireHosts()
                host(false)
            } else {
                logger?.warning(.ui, "Tab badge overlay stood down: \(reason), find attempts spent")
            }
            return
        }
        findBudget -= 1
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.Shell.tabBarFindRetryDelay) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.window != nil, self.hosts.isEmpty else { return }
                self.attach()
            }
        }
    }

    static func descendants<T: UIView>(of type: T.Type, in root: UIView) -> [T] {
        var queue: [UIView] = [root]
        var found: [T] = []
        var index = 0
        while index < queue.count {
            let view = queue[index]
            index += 1
            if let match = view as? T { found.append(match) }
            queue.append(contentsOf: view.subviews)
        }
        return found
    }
}
