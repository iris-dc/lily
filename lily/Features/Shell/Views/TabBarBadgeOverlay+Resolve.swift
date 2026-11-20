import UIKit

/// The find, twin and retry half of the overlay, split from the main file under the length limit; the stored
/// state lives in `TabBarBadgeOverlay.swift` and is internal for this extension.
extension TabBarBadgeOverlay.OverlayView {
    /// The Chats item's glyph: inside the expanded platter — the one pane spanning most of the bar
    /// (`TabBadgePlacement.isPlatter`), so the ~100 pt tab-switch transient and a pre-layout zero-width pane never
    /// host — where the item views are the controls in bar order: two parallel trees with identical frames, so the
    /// pick is by x-column (`TabBadgePlacement`). The capsule joins the platter itself, above both item trees,
    /// under the platter's own morph; both state panes' hidden flags feed the twin rule.
    func resolveGlyph(in bar: UITabBar) {
        chatsGlyph = nil
        capsuleUnfit = false
        platter = bar.subviews
            .filter { TabBadgePlacement.isPlatter(paneWidth: $0.bounds.width, barWidth: bar.bounds.width) }
            .max(by: { $0.bounds.width < $1.bounds.width })
        if let platter { chatsGlyph = Self.chatsGlyph(inPlatter: platter) }
        guard let platter, let glyph = chatsGlyph else {
            // The badge stays up through `host(false)`'s sequenced removal: never a blank count.
            host(false)
            scheduleRetry(reason: "Chats glyph not resolved")
            return
        }
        observations.append(glyph.layer.observe(\.bounds) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.reposition()
                self?.applyTwinState()
            }
        })
        observations.append(glyph.layer.observe(\.position) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.reposition()
                self?.applyTwinState()
            }
        })
        observations.append(platter.layer.observe(\.isHidden, options: [.old, .new]) { [weak self] _, change in
            let old = change.oldValue
            let new = change.newValue
            Task { @MainActor [weak self] in self?.platterHiddenChanged(from: old, to: new) }
        })
        syncCircleObservation(of: bar)
        platter.addSubview(capsule)
        refreshCapsule()
        // The first reposition judges the fit; a capsule the platter's clip would cut has stood down already.
        guard !capsuleUnfit else { return }
        host(true)
        applyTwinState()
    }

    static func chatsGlyph(inPlatter platter: UIView) -> UIImageView? {
        let controls = descendants(of: UIControl.self, in: platter).filter { $0.bounds.width > 0 }
        guard let chatIndex = AppTab.shown.firstIndex(of: .chat),
              let column = TabBadgePlacement.chatsColumn(itemColumns: controls.map { $0.frame.minX.rounded() },
                                                         chatIndex: chatIndex,
                                                         expectedTabs: AppTab.shown.count) else { return nil }
        return controls.lazy
            .filter { $0.frame.minX.rounded() == column }
            .compactMap { descendants(of: UIImageView.self, in: $0).first }
            .first
    }

    /// The minimized circle: the narrowest other pane of the platter's own class — a same-class transient would be
    /// wider than the 48 pt circle, and first-in-subview-order would depend on when UIKit mounted what.
    func circlePane(of bar: UITabBar) -> UIView? {
        guard let platter else { return nil }
        return bar.subviews
            .filter { $0 !== platter && type(of: $0) == type(of: platter) }
            .min(by: { $0.bounds.width < $1.bounds.width })
    }

    /// Keeps one hidden-flag observation on the current circle pane, re-synced on every pane churn: the circle may
    /// be created after the attach (the first minimize), and unhiding it changes no sublayers, so only its own
    /// observation can hand the badge back to the riding capsule the moment a collapse starts.
    func syncCircleObservation(of bar: UITabBar) {
        let circle = circlePane(of: bar)
        guard circle !== observedCircle else { return }
        observedCircle = circle
        // A different circle is a different morph context: stale direction memory must not outlive it.
        clearMorphMemory(reason: "circle pane changed")
        circleObservation = circle?.layer.observe(\.isHidden, options: [.old, .new]) { [weak self] _, change in
            let old = change.oldValue
            let new = change.newValue
            Task { @MainActor [weak self] in self?.circleHiddenChanged(from: old, to: new) }
        }
    }

    /// A real platter transition (same-value KVO writes are ignored): hiding is a collapse settle — the one
    /// moment the missing-circle warning can be judged — and unhiding beside a visible circle is an expand
    /// starting, the twin full from that first frame.
    func platterHiddenChanged(from old: Bool?, to new: Bool?) {
        guard let new, old != new else { return }
        if new {
            if observedCircle == nil, !warnedNoCircle {
                warnedNoCircle = true
                logger?.warning(.ui, "Tab badge overlay: collapse settled with no circle pane resolved")
            }
            clearMorphMemory(reason: "platter hid")
        } else if let bar, circlePane(of: bar)?.isHidden == false {
            setMorphMemory(.platter)
        }
        applyTwinState()
        diagnose("platter hidden=\(new)")
    }

    /// A real circle transition: hiding is an expand settle; unhiding beside a visible platter is a collapse
    /// starting, the capsule riding from that frame.
    func circleHiddenChanged(from old: Bool?, to new: Bool?) {
        guard let new, old != new else { return }
        if new {
            clearMorphMemory(reason: "circle hid")
        } else if let platter, !platter.isHidden {
            setMorphMemory(.circle)
        }
        applyTwinState()
        diagnose("circle hidden=\(new)")
    }

    /// Writes the morph direction; any pane hiding or a newer write supersedes it, and the expand memory alone
    /// also expires on `AppConfig.Shell.twinExpandMemoryGrace` — a reversed or abandoned expand fires no pane
    /// event, so without the grace the twin would hang static over the reversed collapse until its settle.
    func setMorphMemory(_ pane: TabBadgePlacement.Pane) {
        lastUnhiddenPane = pane
        morphMemoryGeneration += 1
        diagnose("memory=\(pane)")
        guard pane == .platter else { return }
        let generation = morphMemoryGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.Shell.twinExpandMemoryGrace) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.morphMemoryGeneration == generation else { return }
                self.lastUnhiddenPane = nil
                self.applyTwinState()
                self.diagnose("expand memory expired")
            }
        }
    }

    func clearMorphMemory(reason: @autoclosure () -> String) {
        morphMemoryGeneration += 1
        guard lastUnhiddenPane != nil else { return }
        lastUnhiddenPane = nil
        diagnose("memory cleared: \(reason())")
    }

    /// One owner for who draws the badge (`TabBadgePlacement.badgeDrawer`): the bar-level twin at the capsule's
    /// converted spot, the riding capsule, or — stood down — neither carrier touched, because the sequenced
    /// hand-back owns their removal and flipping them here would show a shaved capsule at a misfit spot for a
    /// frame. Only a count of zero hides both imperatively; the twin and capsule never draw together (stacked
    /// copies would double the antialiased edges), and the swap lands in one turn at the same spot.
    func applyTwinState() {
        if capsule.image == nil {
            twin.isHidden = true
            capsule.isHidden = true
            return
        }
        guard let bar, let platter, capsule.window != nil else { return }
        let drawer = TabBadgePlacement.badgeDrawer(hosting: isHosting,
                                                   platterHidden: platter.isHidden,
                                                   circleHidden: circlePane(of: bar)?.isHidden,
                                                   lastUnhidden: lastUnhiddenPane)
        #if DEBUG
        let wasShown = twin.superview != nil && !twin.isHidden
        #endif
        switch drawer {
        case .standDown:
            return
        case .twin:
            twin.image = capsule.image
            twin.bounds.size = capsule.bounds.size
            twin.center = bar.convert(capsule.center, from: platter)
            if twin.superview !== bar { bar.addSubview(twin) }
            twin.isHidden = false
            capsule.isHidden = true
        case .ride:
            twin.isHidden = true
            capsule.isHidden = false
        }
        #if DEBUG
        let shows = drawer == .twin
        if shows != wasShown {
            diagnose("twin \(shows ? "on" : "off") drawer=\(drawer) memory=\(String(describing: lastUnhiddenPane))")
        }
        #endif
    }

    /// Debug-only: mirrors the event through the facade (an attached console and `SpyLogger` see it) and records
    /// it with a 2 s bar-shape tail to the pullable file (`BadgePaneDiagnostics`); release builds evaluate nothing.
    func diagnose(_ event: @autoclosure () -> String) {
        #if DEBUG
        let message = event()
        logger?.debug(.ui, "Tab badge: \(message)")
        BadgePaneDiagnostics.shared.note(message, bar: bar, twin: twin, capsule: capsule)
        #endif
    }

    /// The bar joins the window a few frames after this view does (SwiftUI adds its UIKit backing separately),
    /// so a failed find retries on short deferrals; the budget ends the search, so it never becomes polling.
    /// A search that spends it says so once: the fallback composite is correct but silent, and without the line
    /// a lost bar would never be noticed.
    func scheduleRetry(reason: String) {
        guard window != nil else { return }
        guard findBudget > 0 else {
            logger?.warning(.ui, "Tab badge overlay stood down: \(reason), find attempts spent")
            return
        }
        findBudget -= 1
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.Shell.tabBarFindRetryDelay) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.window != nil, self.chatsGlyph == nil else { return }
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
