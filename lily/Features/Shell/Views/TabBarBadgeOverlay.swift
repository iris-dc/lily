import SwiftUI
import UIKit

/// Rides the Chats unread capsule inside the UIKit-backed floating tab bar's expanded platter pane, so the pane's
/// own collapse morph carries it: motion, fade and hiding are the platter's, in lockstep by construction, with no
/// timing code of ours. A capsule anchored to the bar itself stayed put while the platter animated away — the morph
/// never touches the items' model geometry, so nothing outside the pane inherits it, and a hand-tuned fade ran on
/// its own clock beside the morph's. SwiftUI's `TabView` is backed by a real `UITabBar` holding one pane per state
/// (the wide platter, the minimized circle), swapped by visibility; this view finds the bar (bounded retries, knobs
/// in `AppConfig.Shell`; a hierarchy churn starts a fresh search with the whole budget again), the Chats item inside
/// the platter and its glyph image view (`TabBadgePlacement`), then keeps one capsule `UIImageView` as a direct
/// platter subview — above both of the platter's parallel item trees, whose selection styling could cover or mask a
/// capsule parented deeper — at the owner-tuned offset converted into platter coordinates, pixel-identical to the
/// composite at rest; the platter clips to its bounds, so a capsule the clip would cut stands down to the composite
/// instead (the fit re-judged on every layout move). The minimized circle pane never contains the capsule, so the bare circle stays bare. KVO on
/// the glyph's layer re-positions the capsule when layout really moves it, a pane or item churn re-finds what UIKit
/// re-created, and the capsule reports its own eviction (a re-created item dies with its subviews, which no observed
/// layer announces), so a dead host never silently takes the count with it. Fragile by nature: only the `UITabBar`
/// class is public, the pane and item shapes and the morph's choreography are observed behaviour, not API.
/// `onHosting` tells `MainTabView` who carries the count: `true` while the capsule rides the platter (the label
/// hands the bar the plain template glyph), `false` whenever the hierarchy is missing or not the expected shape —
/// the label then composites the count into the glyph as before, so an unread count is never lost. Both handoffs
/// keep the count on screen: the leaving carrier stays until the arriving one has had a body pass, so a handoff may
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
        private weak var platter: UIView?
        private weak var chatsGlyph: UIImageView?
        private let capsule = TabBadgeCapsuleView()
        private lazy var glyphSize = TabBadgeRenderer.glyphSize(symbol: DesignTokens.Symbols.chat)
        private var observations: [NSKeyValueObservation] = []
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
            // Above the selection lens, which UIKit re-adds over the selected item: its glass magnifies and blooms
            // a capsule under it (filmed), and a z-position outranks any subview re-ordering without churning it.
            capsule.layer.zPosition = DesignTokens.TabBar.badgeZPosition
            capsule.onDetach = { [weak self] in self?.capsuleWasEvicted() }
            findBudget = AppConfig.Shell.tabBarFindAttempts
            attach()
        }

        func teardown() {
            // The eviction report is for a host dying mid-ride; the overlay leaving takes the capsule on purpose.
            capsule.onDetach = nil
            observations.removeAll()
            capsule.removeFromSuperview()
            bar = nil
            platter = nil
            chatsGlyph = nil
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
            bar = window.flatMap { Self.descendants(of: UITabBar.self, in: $0).first }
            guard let bar else {
                // A stale resolved glyph would block the retry's re-attach guard and strand the hand-back: a bar
                // that left the window takes the ride with it, so the composite carries the count while the search
                // runs again.
                platter = nil
                chatsGlyph = nil
                host(false)
                scheduleRetry(reason: "no tab bar in the window")
                return
            }
            observations.append(bar.layer.observe(\.sublayers) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.panesDidChurn() }
            })
            for pane in bar.subviews {
                observations.append(pane.layer.observe(\.sublayers) { [weak self] _, _ in
                    Task { @MainActor [weak self] in self?.itemsDidChurn() }
                })
            }
            resolveGlyph(in: bar)
        }

        /// Re-attaches only when the platter itself left the bar or the resolved host died; the bar's layer churns
        /// on every state swap — the ~100 pt transient pane joins and leaves on each tab switch, and UIKit re-fronts
        /// panes — and a full tear-down per churn would re-create every observation for nothing.
        private func panesDidChurn() {
            guard let bar else { return }
            let platterLeft = platter.map { $0.superview !== bar } ?? true
            if platterLeft || hostIsDead { churnedAttach() }
        }

        /// An item view re-created inside a pane (a language change rebuilds the titles) kills the resolved glyph
        /// without churning the bar's own panes.
        private func itemsDidChurn() {
            guard bar != nil, hostIsDead else { return }
            churnedAttach()
        }

        /// A dead host: the glyph or the mounted capsule out of the window. While stood down the glyph is nil, so
        /// any churn is a fresh chance to resolve.
        private var hostIsDead: Bool {
            chatsGlyph?.window == nil || (isHosting && capsule.window == nil)
        }

        /// A churn is a fresh hierarchy, so the search earns its whole budget again; only the timer retries
        /// spend it. Without this, a late churn that found the budget spent stood down silently for good.
        private func churnedAttach() {
            findBudget = AppConfig.Shell.tabBarFindAttempts
            attach()
        }

        /// The host item died with the capsule aboard — nothing observed announces a wholesale item re-creation,
        /// so the capsule reports its own eviction. Deferred, because `didMoveToWindow` lands inside UIKit's
        /// hierarchy surgery, and re-checked at delivery: a teardown or stand-down removes the capsule on purpose
        /// (`isHosting` is already false then) and must not re-attach.
        private func capsuleWasEvicted() {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil, self.isHosting, self.capsule.window == nil else { return }
                self.churnedAttach()
            }
        }

        /// Tells `MainTabView` who carries the count, deduplicated and deferred: KVO can fire inside a UIKit layout
        /// pass, and the handler writes SwiftUI state. The closure is read at delivery, not at the call
        /// (`updateUIView` may have replaced it), and a flip back before delivery supersedes the older message. On a
        /// stand-down the capsule leaves in the completion of the transaction whose commit carries the composite's
        /// body pass — a brief double-draw, never a blank count (a bare second queue hop could still beat the
        /// commit under load).
        private func host(_ hosting: Bool) {
            guard hosting != isHosting else { return }
            isHosting = hosting
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isHosting == hosting else { return }
                self.onHosting?(hosting)
                guard !hosting else { return }
                CATransaction.setCompletionBlock { [weak self] in
                    MainActor.assumeIsolated {
                        guard let self, !self.isHosting else { return }
                        self.capsule.removeFromSuperview()
                    }
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
            guard let platter, let glyph = chatsGlyph, capsule.image != nil else { return }
            let center = glyph.convert(CGPoint(x: glyph.bounds.midX, y: glyph.bounds.midY), to: platter)
            capsule.center = TabBadgePlacement.capsuleCenter(glyphCenter: center, glyphSize: glyphSize)
            if platter.bounds.insetBy(dx: -0.5, dy: -0.5).contains(capsule.frame) { return }
            // The platter clips to its bounds, so a capsule its clip would cut (a layout pushing the glyph to the
            // pane's edge) hands the count back to the composite instead of showing it shaved; model geometry is
            // judged, which the morph's presentation-level animation never moves.
            chatsGlyph = nil
            if isHosting {
                host(false)
            } else {
                capsule.removeFromSuperview()
            }
            scheduleRetry(reason: "the capsule would not fit the platter")
        }
    }
}

/// The overlay's capsule, which reports losing its window: the one way it leaves outside a deliberate removal is its
/// host item dying, and no observed layer announces that.
private final class TabBadgeCapsuleView: UIImageView {
    var onDetach: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { onDetach?() }
    }
}

/// The find half of the overlay, outside the type body under the length limit; a same-file extension, so the
/// stored state stays private.
private extension TabBarBadgeOverlay.OverlayView {
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
            Task { @MainActor [weak self] in self?.reposition() }
        })
        observations.append(glyph.layer.observe(\.position) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.reposition() }
        })
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
