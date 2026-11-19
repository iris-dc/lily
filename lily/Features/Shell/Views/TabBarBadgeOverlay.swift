import SwiftUI
import UIKit

/// Floats the Chats unread capsule over the UIKit-backed floating tab bar, so the count can fade with the bar's
/// collapse morph: swapping a composited glyph image on the binary minimize state dropped the count in one frame,
/// jumped the capsule and let the still-small circle cut it mid-expand. SwiftUI's `TabView` is backed by a real
/// `UITabBar` holding one pane per state (the wide platter, the minimized circle), swapped by visibility; this view
/// finds the bar (bounded retries, knobs in `AppConfig.Shell`; a hierarchy churn starts a fresh search with the whole
/// budget again), the Chats item inside the widest pane (`TabBadgePlacement`) and the item's glyph image view, then
/// keeps one capsule `UIImageView` above the panes — a bar subview, so the bar's own hiding carries it, which no
/// pane's clip can cut — at the owner-tuned offset, pixel-identical to the composite at rest. KVO on the panes'
/// layers drives the capsule's alpha through the minimize rule (`TabBarCollapse`, a `UIView` fade instead of an
/// image swap), KVO on the glyph's layer re-positions it, and a pane or item churn re-finds what UIKit re-created.
/// Fragile by nature: only the `UITabBar` class is public, the pane and item shapes are observed behaviour, not API.
/// `onHosting` tells `MainTabView` who carries the count: `true` while the overlay rides the bar (the label hands
/// the bar the plain template glyph), `false` whenever the hierarchy is missing or not the expected shape — the
/// label then composites the count into the glyph as before, so an unread count is never lost. Both handoffs keep
/// the count on screen: the leaving carrier stays until the arriving one has had a body pass, so a handoff may
/// double-draw briefly but never blanks.
struct TabBarBadgeOverlay: UIViewRepresentable {
    let count: Int
    let renderer: TabBadgeRenderer
    let logger: any Logging
    let onHosting: (Bool) -> Void

    func makeUIView(context: Context) -> OverlayView { OverlayView() }

    func updateUIView(_ view: OverlayView, context: Context) {
        view.onHosting = onHosting
        view.logger = logger
        view.renderer = renderer
        view.count = count
    }

    static func dismantleUIView(_ view: OverlayView, coordinator: ()) {
        view.teardown()
        // Nothing may call back into a dismantled representable; teardown has booked the final hand-back already.
        view.onHosting = nil
    }

    final class OverlayView: UIView {
        var onHosting: ((Bool) -> Void)?
        var logger: (any Logging)?
        var renderer: TabBadgeRenderer?
        var count = 0 {
            didSet { if count != oldValue { refreshCapsule() } }
        }

        private weak var bar: UITabBar?
        private weak var chatsGlyph: UIImageView?
        private let capsule = UIImageView()
        private lazy var glyphSize = TabBadgeRenderer.glyphSize(symbol: DesignTokens.Symbols.chat)
        private var observations: [NSKeyValueObservation] = []
        /// The observed panes by identity, so a sublayer churn re-attaches only when the pane set itself changed.
        private var observedPanes: [ObjectIdentifier] = []
        /// The last settled phase, unknown until the first read: an attach mid-morph must err visible
        /// (`TabBarCollapse.settle`), not fade toward a guessed endpoint.
        private var settled: TabBarCollapse.Phase?
        private var isFadedOut = false
        private var hasAppliedState = false
        private var isHosting = false
        private var findBudget = 0

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else {
                teardown()
                return
            }
            capsule.isUserInteractionEnabled = false
            // The tab's accessibility value stays the one VoiceOver seam for the count.
            capsule.isAccessibilityElement = false
            findBudget = AppConfig.Shell.tabBarFindAttempts
            hasAppliedState = false
            settled = nil
            attach()
        }

        func teardown() {
            observations.removeAll()
            observedPanes = []
            // Removed at once, not sequenced: the overlay itself is leaving, usually with the bar it rides.
            capsule.removeFromSuperview()
            bar = nil
            chatsGlyph = nil
            hasAppliedState = false
            settled = nil
            guard isHosting else { return }
            isHosting = false
            // Captured strongly: the hand-back to the composite must land even if this view is deallocated first.
            let tell = onHosting
            DispatchQueue.main.async { tell?(false) }
        }

        /// Finds the bar, observes its panes and resolves the Chats glyph; observing the bar's and panes' sublayers
        /// catches a pane or item view UIKit re-creates.
        private func attach() {
            observations.removeAll()
            observedPanes = []
            bar = window.flatMap { Self.descendants(of: UITabBar.self, in: $0).first }
            guard let bar else {
                scheduleRetry(reason: "no tab bar in the window")
                return
            }
            observations.append(bar.layer.observe(\.sublayers) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.panesDidChurn() }
            })
            observedPanes = panes(of: bar).map(ObjectIdentifier.init)
            for pane in panes(of: bar) {
                observations.append(pane.layer.observe(\.isHidden) { [weak self] _, _ in
                    Task { @MainActor [weak self] in self?.applyState() }
                })
                observations.append(pane.layer.observe(\.opacity) { [weak self] _, _ in
                    Task { @MainActor [weak self] in self?.applyState() }
                })
                observations.append(pane.layer.observe(\.sublayers) { [weak self] _, _ in
                    Task { @MainActor [weak self] in self?.itemsDidChurn() }
                })
            }
            resolveGlyph(in: bar)
            applyState()
        }

        /// The bar's state panes: its subviews short of the capsule this view added itself.
        private func panes(of bar: UITabBar) -> [UIView] {
            bar.subviews.filter { $0 !== capsule }
        }

        /// Re-attaches only when the pane set itself changed or the resolved glyph died with a re-created item;
        /// the bar's layer churns on every state swap, and a full tear-down per churn would re-create every
        /// observation for nothing.
        private func panesDidChurn() {
            guard let bar else { return }
            if panes(of: bar).map(ObjectIdentifier.init) != observedPanes || chatsGlyph?.window == nil {
                churnedAttach()
            } else {
                applyState()
            }
        }

        /// An item view re-created inside a pane (a language change rebuilds the titles) kills the resolved glyph
        /// without churning the bar's own panes.
        private func itemsDidChurn() {
            guard bar != nil else { return }
            if chatsGlyph?.window == nil { churnedAttach() }
        }

        /// A churn is a fresh hierarchy, so the search earns its whole budget again; only the timer retries
        /// spend it. Without this, a late churn that found the budget spent stood down silently for good.
        private func churnedAttach() {
            findBudget = AppConfig.Shell.tabBarFindAttempts
            attach()
        }

        /// Tells `MainTabView` who carries the count, deduplicated and deferred: KVO can fire inside a UIKit layout
        /// pass, and the handler writes SwiftUI state. The closure is read at delivery, not at the call
        /// (`updateUIView` may have replaced it), and a flip back before delivery supersedes the older message. On a
        /// stand-down the capsule leaves only after the composite's body pass has had a turn — a brief double-draw,
        /// never a blank count.
        private func host(_ hosting: Bool) {
            guard hosting != isHosting else { return }
            isHosting = hosting
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isHosting == hosting else { return }
                self.onHosting?(hosting)
                guard !hosting else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self, !self.isHosting else { return }
                    self.capsule.removeFromSuperview()
                }
            }
        }

        private func refreshCapsule() {
            guard let renderer else { return }
            let image = renderer.capsule(count: count, badgeColor: UIColor(Color.lilyAccent))
            capsule.image = image
            capsule.isHidden = image == nil
            capsule.bounds.size = image?.size ?? .zero
            reposition()
        }

        private func reposition() {
            guard let bar, let glyph = chatsGlyph, capsule.image != nil else { return }
            let center = glyph.convert(CGPoint(x: glyph.bounds.midX, y: glyph.bounds.midY), to: bar)
            capsule.center = TabBadgePlacement.capsuleCenter(glyphCenter: center, glyphSize: glyphSize)
            // Re-fronting unconditionally would churn the bar's sublayers on every KVO tick and feed the
            // observation back to itself.
            if bar.subviews.last !== capsule { bar.bringSubviewToFront(capsule) }
        }

        /// Fades the capsule with the bar's morph: out from the moment a collapse starts (the circle pane joins the
        /// platter on screen), fully out while minimized, and back in the moment the expand starts — an alpha
        /// animation a swapped composite could never give. Mid-morph the direction is the opposite of the last
        /// settled state, so a morph abandoned midway fades back at the next settle; the first read seeds the
        /// settled state (`TabBarCollapse.settle`), erring visible when it lands mid-morph. The first application
        /// snaps (no fade-in at startup); a re-attach with an unchanged target leaves a running fade alone.
        private func applyState() {
            guard let bar else { return }
            let widths = panes(of: bar)
                .filter { !$0.isHidden && $0.alpha > DesignTokens.TabBar.paneVisibleAlpha }
                .map { $0.bounds.width }
            let phase = TabBarCollapse.phase(visiblePaneWidths: widths, barWidth: bar.bounds.width)
            let settledPhase = TabBarCollapse.settle(current: phase, previous: settled)
            settled = settledPhase
            let fadedOut = TabBarCollapse.fadesOut(phase: phase, settled: settledPhase)
            guard !hasAppliedState || fadedOut != isFadedOut else { return }
            let animated = hasAppliedState
            hasAppliedState = true
            isFadedOut = fadedOut
            let target: CGFloat = fadedOut ? 0 : 1
            guard animated else {
                capsule.alpha = target
                return
            }
            UIView.animate(withDuration: DesignTokens.TabBar.badgeFadeDuration,
                           delay: 0,
                           options: DesignTokens.TabBar.badgeFadeOptions) { self.capsule.alpha = target }
        }
    }
}

/// The find half of the overlay, outside the type body under the length limit; a same-file extension, so the
/// stored state stays private.
private extension TabBarBadgeOverlay.OverlayView {
    /// The Chats item's glyph: inside the widest pane (the expanded platter), the item views are the controls in
    /// bar order — two parallel trees with identical frames, so the pick is by x-column (`TabBadgePlacement`).
    func resolveGlyph(in bar: UITabBar) {
        chatsGlyph = nil
        if let platter = panes(of: bar).max(by: { $0.bounds.width < $1.bounds.width }) {
            chatsGlyph = Self.chatsGlyph(inPlatter: platter)
        }
        guard let glyph = chatsGlyph else {
            // The capsule stays up through `host(false)`'s sequenced removal: never a blank count.
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
        observations.append(glyph.layer.observe(\.contents) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.reposition() }
        })
        bar.addSubview(capsule)
        host(true)
        refreshCapsule()
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
