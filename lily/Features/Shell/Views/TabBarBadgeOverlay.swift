import SwiftUI
import UIKit

/// Rides the Chats unread capsule inside the UIKit-backed floating tab bar's expanded platter pane, so the pane's
/// own collapse morph carries it: motion, fade and hiding are the platter's, in lockstep by construction, with no
/// timing code of ours. SwiftUI's `TabView` is backed by a real `UITabBar` holding one pane per state (the wide
/// platter, the minimized circle), swapped by visibility; this view finds the bar (bounded retries, knobs in
/// `AppConfig.Shell`; a hierarchy churn starts a fresh search with the whole budget again), the Chats item inside
/// the platter and its glyph image view (`TabBadgePlacement`), then keeps one capsule `UIImageView` as a direct
/// platter subview — above both of the platter's parallel item trees, whose selection styling could cover or mask a
/// capsule parented deeper — at the owner-tuned offset converted into platter coordinates, pixel-identical to the
/// composite at rest; the platter clips to its bounds, so a capsule the clip would cut stands down to the composite
/// instead (the fit re-judged on every layout move). The minimized circle pane never contains the capsule, so the
/// bare circle stays bare. The badge is drawn by exactly one of two twins: a bar-level twin at the capsule's own
/// converted spot wherever the platter shows settled or is arriving — on the device, selection glass can mount
/// outside the bar's subviews and the platter content's own glass settle dims what rides inside it, so only a view
/// above the panes keeps the badge steady through tab switches and reads full from the expand's first frame — and
/// the riding capsule only while a collapse morph carries it out, the one moment the badge must move and fade with
/// the pane. The choice is a pure pane-state rule over the two panes' hidden flags and which unhid last
/// (`TabBadgePlacement.twinShows`, `applyTwinState`); the swap lands in one turn at the same spot, so it is
/// pixel-invisible, and only one twin ever draws (stacked copies would double the antialiased edges). KVO on the
/// glyph's layer re-positions the capsule when layout really moves it, a pane or item churn re-finds what UIKit
/// re-created, and the capsule reports its own eviction (a re-created item dies with its subviews, which no
/// observed layer announces), so a dead host never silently takes the count with it. Fragile by nature: only the
/// `UITabBar` class is public, the pane shapes and the morph's choreography are observed behaviour, not API.
/// `onHosting` tells `MainTabView` who carries the count: `true` while the overlay draws it (the label hands the
/// bar the plain template glyph), `false` whenever the hierarchy is missing or not the expected shape — the label
/// then composites the count into the glyph as before, so an unread count is never lost. Both handoffs keep the
/// count on screen: the leaving carrier stays until the arriving one has had a body pass, so a handoff may
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

    /// Stored state stays here; the find, twin and retry half lives in `TabBarBadgeOverlay+Resolve.swift`, whose
    /// extension needs these members internal.
    final class OverlayView: UIView {
        var onHosting: ((Bool) -> Void)?
        var logger: (any Logging)?
        var renderer: TabBadgeRenderer?
        var count = 0 {
            didSet { if count != oldValue { refreshCapsule() } }
        }

        weak var bar: UITabBar?
        weak var platter: UIView?
        weak var chatsGlyph: UIImageView?
        let capsule = TabBadgeCapsuleView()
        /// The capsule's bar-level twin: drawn instead of the capsule wherever the platter shows settled or is
        /// arriving (`applyTwinState`), because glass above or inside the platter can dim a riding capsule while a
        /// bar subview above the panes stays steady; hidden while a collapse morph carries the capsule out.
        let twin = UIImageView()
        lazy var glyphSize = TabBadgeRenderer.glyphSize(symbol: DesignTokens.Symbols.chat)
        var observations: [NSKeyValueObservation] = []
        /// The circle pane's own hidden-flag observation, re-synced per pane churn: the circle may be created after
        /// the attach (the first minimize), and unhiding it changes no sublayers, so only this observation can
        /// switch the badge back to the riding capsule the moment a collapse starts.
        var circleObservation: NSKeyValueObservation?
        weak var observedCircle: UIView?
        /// Which state pane unhid last while the other was visible: the twin rule's morph direction
        /// (`TabBadgePlacement.twinShows`). Nothing until the first morph after an attach (erring to the ride);
        /// any pane hiding is a settle and clears it, and the expand memory expires on a grace
        /// (`setMorphMemory`), so a reversed morph never ghosts a static twin to the settle.
        var lastUnhiddenPane: TabBadgePlacement.Pane?
        /// Cancels a pending expand-memory expiry whenever a newer memory write lands.
        var morphMemoryGeneration = 0
        /// The capsule's fit failed at the current layout: the overlay stands down but keeps the glyph and its
        /// observations, so the same layout moving back re-hosts without a search — a nil'd glyph re-entered
        /// `attach` from our own churn, and the budget replenish made that loop unbounded.
        var capsuleUnfit = false
        /// One warning per attach when a collapse settles with no circle resolved: the device signal that the
        /// class-equality circle pick failed.
        var warnedNoCircle = false
        var isHosting = false
        var findBudget = 0

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
            twin.isUserInteractionEnabled = false
            twin.isAccessibilityElement = false
            twin.layer.zPosition = DesignTokens.TabBar.badgeZPosition
            capsule.onDetach = { [weak self] in self?.capsuleWasEvicted() }
            findBudget = AppConfig.Shell.tabBarFindAttempts
            attach()
        }

        func teardown() {
            // The eviction report is for a host dying mid-ride; the overlay leaving takes the capsule on purpose.
            capsule.onDetach = nil
            observations.removeAll()
            circleObservation = nil
            observedCircle = nil
            morphMemoryGeneration += 1
            lastUnhiddenPane = nil
            capsuleUnfit = false
            warnedNoCircle = false
            capsule.removeFromSuperview()
            twin.removeFromSuperview()
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
        func attach() {
            diagnose("attach")
            observations.removeAll()
            circleObservation = nil
            observedCircle = nil
            // A fresh hierarchy has no morph history or fit verdict; a pending expiry dies with the generation.
            morphMemoryGeneration += 1
            lastUnhiddenPane = nil
            capsuleUnfit = false
            warnedNoCircle = false
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
            for pane in bar.subviews where pane !== twin {
                observations.append(pane.layer.observe(\.sublayers) { [weak self] _, _ in
                    Task { @MainActor [weak self] in self?.itemsDidChurn() }
                })
            }
            resolveGlyph(in: bar)
        }

        /// Re-attaches only when the platter itself left the bar or the resolved host died; the bar's layer churns
        /// on every state swap — transients join and leave on each tab switch, and UIKit re-fronts panes — and a
        /// full tear-down per churn would re-create every observation for nothing. The same churn re-syncs the
        /// circle observation and re-applies the twin rule.
        private func panesDidChurn() {
            guard let bar else { return }
            let platterLeft = platter.map { $0.superview !== bar } ?? true
            if platterLeft || hostIsDead {
                churnedAttach()
            } else {
                syncCircleObservation(of: bar)
                applyTwinState()
                diagnose("panes churned")
            }
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
        /// stand-down the badge leaves in the completion of the transaction whose commit carries the composite's
        /// body pass — a brief double-draw, never a blank count (a bare second queue hop could still beat the
        /// commit under load).
        func host(_ hosting: Bool) {
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
                        self.twin.removeFromSuperview()
                    }
                }
            }
        }

        func refreshCapsule() {
            guard let renderer else { return }
            let image = renderer.capsule(count: count, badgeColor: UIColor(Color.lilyAccent))
            capsule.image = image
            capsule.bounds.size = image?.size ?? .zero
            reposition()
            applyTwinState()
        }

        func reposition() {
            guard let platter, let glyph = chatsGlyph, capsule.image != nil else { return }
            let center = glyph.convert(CGPoint(x: glyph.bounds.midX, y: glyph.bounds.midY), to: platter)
            capsule.center = TabBadgePlacement.capsuleCenter(glyphCenter: center, glyphSize: glyphSize)
            let fits = platter.bounds.insetBy(dx: -0.5, dy: -0.5).contains(capsule.frame)
            if fits {
                guard capsuleUnfit else { return }
                // The layout that pushed the capsule past the platter's clip moved back: the overlay re-hosts
                // without a search — the glyph and its observations never left.
                capsuleUnfit = false
                if capsule.superview !== platter { platter.addSubview(capsule) }
                host(true)
                applyTwinState()
                return
            }
            guard !capsuleUnfit else { return }
            // The platter clips to its bounds, so a capsule its clip would cut (a layout pushing the glyph to
            // the pane's edge) hands the count to the composite instead of showing it shaved; model geometry is
            // judged, which the morph's presentation-level animation never moves.
            capsuleUnfit = true
            if isHosting {
                host(false)
            } else {
                capsule.removeFromSuperview()
            }
        }
    }
}

/// The overlay's capsule, which reports losing its window: the one way it leaves outside a deliberate removal is its
/// host item dying, and no observed layer announces that.
final class TabBadgeCapsuleView: UIImageView {
    var onDetach: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { onDetach?() }
    }
}
