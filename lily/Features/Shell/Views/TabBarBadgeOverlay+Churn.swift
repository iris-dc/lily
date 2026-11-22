import UIKit

/// The churn half of the overlay: how a pane or item churn is judged (dead, stale or noise) and how a hosted
/// hierarchy re-resolves in place, split from `TabBarBadgeOverlay.swift` under the file length limit; the stored
/// state lives there and is internal for this extension.
extension TabBarBadgeOverlay.OverlayView {
    /// Re-attaches only when the platter itself left the bar or a resolved host died or went stale; the bar's
    /// layer churns on every state swap — transients join and leave on each tab switch, and UIKit re-fronts
    /// panes — and a full tear-down per churn would re-create every observation for nothing.
    func panesDidChurn() {
        guard let bar else { return }
        let platterLeft = platter.map { $0.superview !== bar } ?? true
        if platterLeft || hostIsDead {
            churnedAttach()
        } else if platterIsStale {
            diagnose("stale platter")
            churnedAttach()
        } else if hostsAreStale {
            diagnose("stale hosts")
            churnedAttach()
        } else {
            diagnose("panes churned")
        }
    }

    /// An item view re-created inside a pane (a language change rebuilds the titles) kills a resolved glyph
    /// without churning the bar's own panes.
    func itemsDidChurn() {
        guard bar != nil, hostIsDead || hostsAreStale else { return }
        churnedAttach()
    }

    /// A dead host: any glyph no longer drawable, or a mounted capsule out of the window. While stood down the
    /// hosts are empty, so any churn is a fresh chance to resolve.
    private var hostIsDead: Bool {
        hosts.isEmpty
            || hosts.contains { !isDrawable($0.glyph) }
            || (isHosting && hosts.contains { $0.capsule.window == nil })
    }

    /// A pane-level replacement the glyph rules are blind to: the stored platter is no longer the qualifying
    /// widest pane, or it is hidden while another qualifying pane stands. Re-judged on every pane churn; the
    /// minimized state hides the platter with no other qualifying pane, so a plain minimize never trips this.
    private var platterIsStale: Bool {
        guard let bar, let platter else { return false }
        let qualifying = bar.subviews.filter {
            TabBadgePlacement.isPlatter(paneWidth: $0.bounds.width, barWidth: bar.bounds.width)
        }
        guard let widest = qualifying.max(by: { $0.bounds.width < $1.bounds.width }) else { return false }
        if widest !== platter { return true }
        return platter.isHidden && qualifying.contains { !$0.isHidden }
    }

    /// The drawn item trees can be replaced one level below the observed pane layers (filmed: the select
    /// re-stacks the platter's content about a second after it settles), leaving the mounts windowed in a
    /// stale, undrawn subtree while every observed layer stays quiet — so each bar-level churn also verifies
    /// the resolved glyphs are still the drawn trees' glyphs, by count and identity (the pinned pure rule).
    /// Covers the transient one-tree resolve too; an untrusted mid-churn shape answers nothing here and is
    /// left to the dead-host and failure paths.
    private var hostsAreStale: Bool {
        guard let platter, !hosts.isEmpty else { return false }
        let current = Self.chatsGlyphs(inPlatter: platter)
        return TabBadgePlacement.hostsAreStale(current: current.map(ObjectIdentifier.init),
                                               resolved: hosts.compactMap { $0.glyph.map(ObjectIdentifier.init) },
                                               hostCount: hosts.count)
    }

    /// A churn is a fresh hierarchy, so the search earns its whole budget again; only the timer retries
    /// spend it. Without this, a late churn that found the budget spent stood down silently for good. A
    /// churn while HOSTING also arms the hand-off grace (the pinned pure rule: once per episode, never
    /// extended): a hosted hierarchy that churned is the device's non-atomic item rebuild whatever channel
    /// noticed it first — the eviction delivery is dropped whenever a churn's hand-off lands before it, so
    /// arming only in the deliveries would miss the filmed route.
    private func churnedAttach() {
        if let deadline = TabBadgePlacement.armedGraceDeadline(isHosting: isHosting,
                                                               graceArmed: graceArmed,
                                                               now: CACurrentMediaTime()) {
            graceArmed = true
            graceDeadline = deadline
        }
        findBudget = AppConfig.Shell.tabBarFindAttempts
        attach()
    }

    /// A host item died with its capsule aboard — nothing observed announces a wholesale item re-creation,
    /// so each capsule reports its own eviction. Deferred, because `didMoveToWindow` lands inside UIKit's
    /// hierarchy surgery, and re-checked at delivery: a teardown or stand-down removes capsules on purpose
    /// (`isHosting` is already false then) and must not re-attach. The delivery re-resolves in the same turn
    /// (`churnedAttach` arms the hand-off grace for any hosted churn): on success `host(true)` is a no-op, so
    /// the label never swaps, and a failure keeps retrying through the grace before any hand-off
    /// (`resolveFailed`; a fresh mount whose first fit judgment trips still hands off at once, its capsules
    /// unmounted synchronously) — the device rebuilds the selected
    /// item non-atomically, and a composite hand-off would visibly crossfade through the rebuilding item.
    func capsuleWasEvicted() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil, self.isHosting,
                  self.hosts.contains(where: { $0.capsule.window == nil }) else { return }
            self.diagnose("evicted")
            self.churnedAttach()
            self.diagnoseChurnOutcome(wasHosting: true)
        }
    }

    /// A glyph died, left its item or its window while repositioning: the same route as an eviction — a
    /// deferred fresh resolve that remounts in place (`churnedAttach` arms the grace when it was hosting; a
    /// fresh mount's fit trip still hands off at once); the fit judgment is skipped that pass (judging a dead
    /// tree could strand or mis-trip the live one).
    func glyphDied() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil,
                  self.hosts.contains(where: {
                      $0.glyph?.superview == nil || !self.isDrawable($0.glyph)
                  }) else { return }
            let wasHosting = self.isHosting
            self.diagnose("glyph died")
            self.churnedAttach()
            self.diagnoseChurnOutcome(wasHosting: wasHosting)
        }
    }

    /// The transition, not the exit state: a grace in flight keeps `isHosting` true with no capsules yet.
    private func diagnoseChurnOutcome(wasHosting: Bool) {
        if wasHosting && isHosting && !hosts.isEmpty {
            diagnose("remounted in place")
        } else {
            diagnose("outcome: hosting \(wasHosting) -> \(isHosting), hosts \(hosts.count)")
        }
    }

    /// A drawable glyph is windowed AND visible up to the platter: the select's re-stack can leave the old
    /// tree windowed but hidden one level below the observed pane layers, so plain window checks cannot see it.
    func isDrawable(_ glyph: UIImageView?) -> Bool {
        Self.isDrawable(glyph, upTo: platter)
    }

    /// The condemnation standard, applied at adoption too (`chatsGlyphs`): windowed with nothing hidden or
    /// effectively transparent (`AppConfig.Shell.tabBarDrawableAlphaMinimum`) walking up to, excluding, the
    /// boundary pane — the select's re-stack leaves the stale tree windowed and layer-rooted with clean
    /// own-flags (the capsule census read mounted, visible-state and right-positioned while the screen showed
    /// no badge), hidden by an ancestor one level below the observed pane layers; the pane itself is excluded
    /// because the minimized state hides the whole pane on purpose.
    static func isDrawable(_ view: UIView?, upTo boundary: UIView?) -> Bool {
        guard let view, view.window != nil else { return false }
        var node: UIView? = view
        while let current = node, current !== boundary {
            if current.isHidden || current.alpha < AppConfig.Shell.tabBarDrawableAlphaMinimum { return false }
            node = current.superview
        }
        return true
    }
}
