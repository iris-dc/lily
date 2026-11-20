import UIKit

/// The find, cover and retry half of the overlay, split from the main file under the length limit; the stored
/// state lives in `TabBarBadgeOverlay.swift` and is internal for this extension.
extension TabBarBadgeOverlay.OverlayView {
    /// The Chats item's glyph: inside the expanded platter — the one pane spanning most of the bar
    /// (`TabBadgePlacement.isPlatter`), so the ~100 pt tab-switch transient and a pre-layout zero-width pane never
    /// host — where the item views are the controls in bar order: two parallel trees with identical frames, so the
    /// pick is by x-column (`TabBadgePlacement`). The capsule joins the platter itself, above both item trees,
    /// under the platter's own morph.
    func resolveGlyph(in bar: UITabBar) {
        chatsGlyph = nil
        platter = bar.subviews
            .filter { TabBadgePlacement.isPlatter(paneWidth: $0.bounds.width, barWidth: bar.bounds.width) }
            .max(by: { $0.bounds.width < $1.bounds.width })
        if let platter { chatsGlyph = Self.chatsGlyph(inPlatter: platter) }
        guard let platter, let glyph = chatsGlyph else {
            // The capsule stays up through `host(false)`'s sequenced removal: never a blank count.
            host(false)
            scheduleRetry(reason: "Chats glyph not resolved")
            return
        }
        observations.append(glyph.layer.observe(\.bounds) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.reposition()
                self?.updateCover()
            }
        })
        observations.append(glyph.layer.observe(\.position) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.reposition()
                self?.updateCover()
            }
        })
        syncCircleObservation(of: bar)
        platter.addSubview(capsule)
        refreshCapsule()
        // The first reposition judges the fit; a capsule the platter's clip would cut has stood down already.
        guard chatsGlyph != nil else { return }
        host(true)
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
    /// observation can clear a mounted cover the moment a morph starts.
    func syncCircleObservation(of bar: UITabBar) {
        let circle = circlePane(of: bar)
        guard circle !== observedCircle else { return }
        observedCircle = circle
        circleObservation = circle?.layer.observe(\.isHidden) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.updateCover() }
        }
    }

    /// A bar subview that is no state pane and not ours: the transient hosting a tab switch's flying glass. Only a
    /// visible view counts — a permanent hidden chrome subview must never mount the cover at rest — but with no
    /// laid-out requirement: the select portal measures zero width exactly while its glass crossfades, the very
    /// frames the cover exists for (a width clause re-opened 1–2-frame dips, filmed).
    func foreignPane(of bar: UITabBar) -> UIView? {
        guard let platter else { return nil }
        return bar.subviews.first { $0 !== switchCover && type(of: $0) != type(of: platter) && !$0.isHidden }
    }

    /// Mirrors the capsule at bar level during a pure tab switch — a transient pane up, no morph underway (the
    /// circle pane hidden; an unresolved circle errs off, a brief blink over a bar-anchored ghost) — at the
    /// capsule's own spot, so the twin is pixel-identical and the handoff invisible.
    func updateCover() {
        guard let bar else { return }
        let covering = TabBadgePlacement.shouldCover(hosting: isHosting,
                                                     capsuleVisible: !capsule.isHidden && capsule.window != nil,
                                                     transientPresent: foreignPane(of: bar) != nil,
                                                     circleHidden: circlePane(of: bar)?.isHidden)
        guard covering else {
            switchCover.removeFromSuperview()
            return
        }
        switchCover.image = capsule.image
        switchCover.bounds.size = capsule.bounds.size
        switchCover.center = bar.convert(capsule.center, from: capsule.superview)
        if switchCover.superview !== bar { bar.addSubview(switchCover) }
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
