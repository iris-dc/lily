import SwiftUI
import UIKit

/// Keeps the minimized circle's Chats glyph plain. The composited label is the one badge, but the minimized
/// bar's 48 pt circle draws bitmaps unscaled and would cut the count at its rim; the owner's spec is the count
/// fading out with the menu instead. The circle pane is its own one-item platter holding one `UIImageView` that
/// UIKit mirrors the tab's image into: whenever that mirror holds one of OUR composites
/// (`TabBadgeRenderer.isComposite` — identity by instance or backing `CGImage`), this view swaps it for the
/// plain template glyph the count-zero label uses, left template so the circle tints and scales it natively,
/// exactly as it draws the other tabs' template glyphs. Identity is the whole rule: another tab's glyph is
/// never ours and never touched, and the replacement itself fails the check, so the re-apply cannot loop. The
/// swap runs synchronously inside the mirror's KVO callout, joining the transaction that stamped the composite —
/// a deferred swap could commit one rim-cut frame on a count change while minimized. A churn of the bar's panes
/// or of the circle's own subviews re-validates the bound mirror with the condemnation standard (drawable up
/// to, excluding, its pane — which hides at rest by design — and the pane still circle-narrow) and re-runs the
/// full search with a fresh budget when it fails; the SwiftUI update re-arms a guard whose adopted bar died
/// (the shell rebuild swaps hierarchies under a live overlay, and a dead bar's observations can never fire
/// again; the count ferried through the representable is what makes those updates land — SwiftUI skips an
/// unchanged value); a search that spends its budget with no bar says so once through the facade. No positioning, no
/// capsules, no handoffs: `MainTabView` keeps the composite label unconditionally, so a guard that never finds
/// its circle costs only the rim-cut count this seam exists to remove.
struct TabBarBareCircle: UIViewRepresentable {
    /// Carried only so this representable's VALUE changes with the count: SwiftUI skips `updateUIView` when the
    /// stored value is unchanged, and the count change is the one guaranteed update after a shell swap — the
    /// re-arm's channel (`renderer` and `logger` are the same instances for the app's lifetime).
    let count: Int
    let renderer: TabBadgeRenderer
    let logger: any Logging

    func makeUIView(context: Context) -> GuardView { GuardView() }

    func updateUIView(_ view: GuardView, context: Context) {
        view.renderer = renderer
        view.logger = logger
        view.rearmIfDetached()
    }

    static func dismantleUIView(_ view: GuardView, coordinator: ()) {
        view.teardown()
    }

    /// Only a pane no wider than the minimized circle's cap is a candidate for the swap: the expanded platter
    /// and the ~100 pt tab-switch transient never qualify, and a pre-layout zero width trusts nothing. Judged
    /// on model bounds, which the collapse morph (a presentation-level animation) never moves.
    static func isMinimizedCircle(paneWidth: CGFloat) -> Bool {
        paneWidth > 0 && paneWidth <= AppConfig.Shell.tabBarCircleMaxWidth
    }

    /// Nothing hidden or effectively transparent from `view` up to, excluding, `boundary` (the pane itself
    /// hides at rest by design); the caller checks the window separately. A mirror can be left windowed inside
    /// a stale, undrawn subtree, which no own-flag betrays.
    static func isDrawable(_ view: UIView, upTo boundary: UIView) -> Bool {
        var node: UIView? = view
        while let current = node, current !== boundary {
            if current.isHidden || current.alpha < AppConfig.Shell.tabBarDrawableAlphaMinimum { return false }
            node = current.superview
        }
        return true
    }

    final class GuardView: UIView {
        var renderer: TabBadgeRenderer?
        var logger: (any Logging)?
        private weak var bar: UITabBar?
        private weak var circle: UIView?
        private weak var mirror: UIImageView?
        private var observations: [NSKeyValueObservation] = []
        private var mirrorObservation: NSKeyValueObservation?
        private var findBudget = 0

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else {
                teardown()
                return
            }
            rearm()
        }

        func teardown() {
            observations.removeAll()
            mirrorObservation = nil
            mirror = nil
            circle = nil
            bar = nil
        }

        /// The shell rebuild can swap hierarchies under a live guard: a fresh view adopts the OUTGOING bar
        /// during the crossfade and its observations die with it, with no churn left to fire. The representable
        /// carries the count so its value changes and the update lands (an unchanged value is skipped) — the
        /// recovery channel, no polling; a healthy update re-judges the mirror, the belt to the KVO braces.
        func rearmIfDetached() {
            guard window != nil else { return }
            guard bar == nil || bar?.window == nil else {
                keepPlain()
                return
            }
            rearm()
        }

        private func rearm() {
            findBudget = AppConfig.Shell.tabBarFindAttempts
            attach()
        }

        private func attach() {
            observations.removeAll()
            mirrorObservation = nil
            mirror = nil
            circle = nil
            bar = window.flatMap { Self.descendants(of: UITabBar.self, in: $0).first }
            guard let bar else {
                scheduleRetry()
                return
            }
            observations.append(bar.layer.observe(\.sublayers) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.revalidate() }
            })
            findCircle(in: bar)
        }

        /// Any churn — the bar's panes or the circle's own subviews — re-judges the bound mirror; a failure
        /// re-runs the full search with a fresh budget (the circle is re-created at UIKit's pleasure, and an
        /// image view can be rebuilt inside a persisting pane, which only the pane's own layer announces).
        private func revalidate() {
            if mirrorIsValid {
                keepPlain()
                return
            }
            rearm()
        }

        /// The condemnation standard: the mirror still windowed inside ITS pane, drawable below the pane, and
        /// the pane still circle-narrow under the bar.
        private var mirrorIsValid: Bool {
            guard let bar, let circle, let mirror,
                  circle.superview === bar,
                  TabBarBareCircle.isMinimizedCircle(paneWidth: circle.bounds.width),
                  mirror.window != nil, mirror.isDescendant(of: circle),
                  TabBarBareCircle.isDrawable(mirror, upTo: circle) else { return false }
            return true
        }

        private func findCircle(in bar: UITabBar) {
            let pane = bar.subviews.first { TabBarBareCircle.isMinimizedCircle(paneWidth: $0.bounds.width) }
            guard let pane,
                  let imageView = Self.descendants(of: UIImageView.self, in: pane)
                      .first(where: { TabBarBareCircle.isDrawable($0, upTo: pane) }) else {
                mirrorObservation = nil
                mirror = nil
                circle = nil
                scheduleRetry()
                return
            }
            circle = pane
            observations.append(pane.layer.observe(\.sublayers) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.revalidate() }
            })
            mirror = imageView
            // Synchronous on purpose: the swap joins the transaction that stamped the composite into the
            // mirror, so a count change while minimized never commits a rim-cut frame; the identity rule
            // bounds the re-entrant callout to one no-op.
            mirrorObservation = imageView.observe(\.image) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.keepPlain() }
            }
            keepPlain()
        }

        /// The swap, on identity alone: only our composite is replaced, so another tab's glyph and the plain
        /// replacement itself never re-trigger.
        private func keepPlain() {
            guard let mirror, let renderer, renderer.isComposite(mirror.image) else { return }
            let configuration = UIImage.SymbolConfiguration(weight: DesignTokens.TabBar.symbolWeight)
            mirror.image = UIImage(systemName: DesignTokens.Symbols.chat, withConfiguration: configuration)
        }

        /// The bar lands a few frames after this view, and the circle only exists after the first minimize: a
        /// short bounded search, no steady-state polling. A spent search with no bar says so once — the
        /// composite stays correct, but a silently lost bar would never be noticed — and a stale deferral
        /// no-ops once a mirror is bound.
        private func scheduleRetry() {
            guard window != nil else { return }
            guard findBudget > 0 else {
                if bar == nil {
                    logger?.warning(.ui, "Tab bar circle guard stood down: no tab bar in the window")
                }
                return
            }
            findBudget -= 1
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.Shell.tabBarFindRetryDelay) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, self.window != nil, self.mirror == nil else { return }
                    if let bar = self.bar {
                        self.findCircle(in: bar)
                    } else {
                        self.attach()
                    }
                }
            }
        }

        private static func descendants<T: UIView>(of type: T.Type, in root: UIView) -> [T] {
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
}
