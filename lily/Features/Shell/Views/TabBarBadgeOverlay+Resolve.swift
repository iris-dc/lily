import UIKit

/// The find and retry half of the overlay, split from the main file under the length limit; the stored state
/// lives in `TabBarBadgeOverlay.swift` and is internal for this extension.
extension TabBarBadgeOverlay.OverlayView {
    /// The Chats item's glyph: inside the expanded platter — the one pane spanning most of the bar
    /// (`TabBadgePlacement.isPlatter`), so the ~100 pt tab-switch transient and a pre-layout zero-width pane never
    /// host — where the item views are the controls in bar order: two parallel trees with identical frames, so the
    /// pick is by x-column (`TabBadgePlacement`). The capsule joins the platter itself, above both item trees,
    /// under the platter's own morph.
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
            Task { @MainActor [weak self] in self?.reposition() }
        })
        observations.append(glyph.layer.observe(\.position) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.reposition() }
        })
        platter.addSubview(capsule)
        refreshCapsule()
        // The first reposition judges the fit; a capsule the platter's clip would cut has stood down already.
        guard !capsuleUnfit else { return }
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

    /// Debug-only: mirrors the event through the facade (an attached console and `SpyLogger` see it) and records
    /// it with a 2 s bar-shape tail to the pullable file (`BadgePaneDiagnostics`); release builds evaluate nothing.
    func diagnose(_ event: @autoclosure () -> String) {
        #if DEBUG
        let message = event()
        logger?.debug(.ui, "Tab badge: \(message)")
        BadgePaneDiagnostics.shared.note(message, bar: bar, capsule: capsule)
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
