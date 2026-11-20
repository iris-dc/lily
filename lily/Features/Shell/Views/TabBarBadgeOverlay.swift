import SwiftUI
import UIKit

/// Draws the Chats unread capsule inside the UIKit-backed floating tab bar, as part of the Chats item itself. The
/// owner's spec: the badge behaves exactly like the bar's own icons — same scale, position and motion in every bar
/// animation — with one difference, its opacity fading out as the menu shrinks and back in as it expands. A phone
/// recording diagnosed why a platter-sibling capsule failed that with Chats selected: the selection lens draws a
/// magnified COPY of the selected item's own subtree through a portal above its glass, so the icons read crisp
/// (their copies replace them) while anything outside the item stays in the dimmed backdrop beneath the glass. No
/// z-position can win that fight; only content inside the item is copied. The capsule is therefore a subview of
/// the Chats item, directly above its glyph image view — and one per parallel item tree: the expanded platter
/// draws two full trees at identical frames (`SelectedContentView` and `ContentView`, both fully opaque in every
/// settled state, a `DestOutView` punching the backdrop out under the lens, per the hierarchy probe), and which
/// tree the lens samples or a transition fades is not observable, so each tree carries its own pixel-identical
/// capsule: whatever a tree does — lens copy, crossfade, morph transform, the platter's collapse — its capsule
/// gets exactly as its glyph does, by construction. The minimized circle pane is its own platter and never hosts,
/// so the bare circle stays bare. SwiftUI's `TabView` is backed by a real `UITabBar`; this view finds the bar
/// (bounded retries, knobs in `AppConfig.Shell`; a hierarchy churn starts a fresh search with the whole budget),
/// the expanded platter (`TabBadgePlacement.isPlatter`), the Chats items by x-column over the item trees — whole
/// trees only: every column must carry the same number of controls and every Chats item its glyph, or nothing is
/// trusted — then keeps one capsule per item at the owner-tuned offset in the item's own coordinates,
/// pixel-identical to the composite at rest. The platter clips to its bounds, so a capsule the clip would cut
/// (judged by converting each capsule's frame into the platter) stands down to the composite behind the
/// `capsuleUnfit` flag, the glyphs and observations kept, and re-mounts when the layout fits again. KVO on each
/// glyph's layer re-positions the capsules when layout really moves them (a burst coalesces into one pass), a
/// pane or item churn re-finds what UIKit re-created, and each capsule reports its own eviction (a re-created
/// item dies with its subviews, which no observed layer announces) — a dead host hands the count to the composite
/// first and re-resolves after. Fragile by nature: only the `UITabBar` class is public; the pane and item shapes
/// are observed behaviour, not API. `onHosting` tells `MainTabView` who carries the count: `true` while the
/// capsules ride (the label hands the bar the plain template glyph), `false` whenever the hierarchy is missing or
/// not the expected shape — the label then composites the count into the glyph as before, so an unread count is
/// never lost. Both handoffs keep the count on screen: a failing resolve retires the mounted capsules to a
/// leaving list that the composite's commit sweeps (and any next successful mount sweeps first), and a successful
/// one replaces them only after the new capsules are mounted — a handoff may double-draw briefly but never blanks.
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

    /// Stored state stays here; the find, mount and retry half lives in `TabBarBadgeOverlay+Resolve.swift`,
    /// whose extension needs these members internal.
    final class OverlayView: UIView {
        var onHosting: ((Bool) -> Void)?
        var logger: (any Logging)?
        var renderer: TabBadgeRenderer?
        var count = 0 {
            didSet { if count != oldValue { refreshCapsules() } }
        }

        weak var bar: UITabBar?
        weak var platter: UIView?
        var hosts: [BadgeHost] = []
        /// Capsules a failed resolve retired while they were on screen: they stay mounted (silenced) until the
        /// composite's commit sweeps them — stripping them synchronously blanked the count for the frames before
        /// the commit.
        var leavingCapsules: [TabBadgeCapsuleView] = []
        lazy var glyphSize = TabBadgeRenderer.glyphSize(symbol: DesignTokens.Symbols.chat)
        var observations: [NSKeyValueObservation] = []
        /// A capsule's fit failed at the current layout: the overlay stands down but keeps the glyphs and their
        /// observations, so the same layout moving back re-mounts without a search — a nil'd glyph re-entered
        /// `attach` from our own churn, and the budget replenish made that loop unbounded.
        var capsuleUnfit = false
        var isHosting = false
        var findBudget = 0
        var repositionPending = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else {
                teardown()
                return
            }
            findBudget = AppConfig.Shell.tabBarFindAttempts
            attach()
        }

        func teardown() {
            removeHosts()
            observations.removeAll()
            capsuleUnfit = false
            bar = nil
            platter = nil
            guard isHosting else { return }
            isHosting = false
            // Captured strongly: the hand-back to the composite must land even if this view is deallocated first.
            let tell = onHosting
            DispatchQueue.main.async { tell?(false) }
        }

        /// Finds the bar, observes its panes and resolves the Chats glyphs; observing the bar's and panes'
        /// sublayers catches a pane or item view UIKit re-creates. The resets live here, the one entry of every
        /// search.
        func attach() {
            diagnose("attach")
            observations.removeAll()
            capsuleUnfit = false
            bar = window.flatMap { Self.descendants(of: UITabBar.self, in: $0).first }
            guard let bar else {
                // A bar that left the window takes the ride with it: the hosts retire (so the retry re-attaches)
                // and the composite carries the count while the search runs again.
                platter = nil
                retireHosts()
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
            resolveGlyphs(in: bar)
        }

        /// Re-attaches only when the platter itself left the bar or a resolved host died; the bar's layer churns
        /// on every state swap — transients join and leave on each tab switch, and UIKit re-fronts panes — and a
        /// full tear-down per churn would re-create every observation for nothing.
        private func panesDidChurn() {
            guard let bar else { return }
            let platterLeft = platter.map { $0.superview !== bar } ?? true
            if platterLeft || hostIsDead {
                churnedAttach()
            } else {
                diagnose("panes churned")
            }
        }

        /// An item view re-created inside a pane (a language change rebuilds the titles) kills a resolved glyph
        /// without churning the bar's own panes.
        private func itemsDidChurn() {
            guard bar != nil, hostIsDead else { return }
            churnedAttach()
        }

        /// A dead host: any glyph or mounted capsule out of the window. While stood down the hosts are empty, so
        /// any churn is a fresh chance to resolve.
        private var hostIsDead: Bool {
            hosts.isEmpty
                || hosts.contains { $0.glyph?.window == nil }
                || (isHosting && hosts.contains { $0.capsule.window == nil })
        }

        /// A churn is a fresh hierarchy, so the search earns its whole budget again; only the timer retries
        /// spend it. Without this, a late churn that found the budget spent stood down silently for good.
        func churnedAttach() {
            findBudget = AppConfig.Shell.tabBarFindAttempts
            attach()
        }

        /// Tells `MainTabView` who carries the count, deduplicated and deferred: KVO can fire inside a UIKit
        /// layout pass, and the handler writes SwiftUI state. The closure is read at delivery, not at the call
        /// (`updateUIView` may have replaced it), and a flip back before delivery supersedes the older message.
        /// On a stand-down the capsules leave in the completion of the transaction whose commit carries the
        /// composite's body pass — a brief double-draw, never a blank count (a bare second queue hop could still
        /// beat the commit under load).
        func host(_ hosting: Bool) {
            guard hosting != isHosting else { return }
            isHosting = hosting
            diagnose("host(\(hosting))")
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isHosting == hosting else { return }
                self.onHosting?(hosting)
                guard !hosting else { return }
                CATransaction.setCompletionBlock { [weak self] in
                    MainActor.assumeIsolated {
                        guard let self, !self.isHosting else { return }
                        self.unmountCapsules(self.hosts.map(\.capsule))
                        self.sweepLeaving()
                    }
                }
            }
        }

        /// The capsules show whenever hosted; only a count of zero hides them. Everything else about their
        /// visibility — the collapse fade, the lens copy, a tree crossfade — is the item's own treatment carrying
        /// its content.
        func refreshCapsules() {
            guard let renderer else { return }
            let image = renderer.capsule(count: count, badgeColor: UIColor(Color.lilyAccent))
            for badgeHost in hosts {
                badgeHost.capsule.image = image
                badgeHost.capsule.isHidden = image == nil
                badgeHost.capsule.bounds.size = image?.size ?? .zero
            }
            reposition()
        }

        func reposition() {
            guard let platter, hosts.first?.capsule.image != nil else { return }
            var allFit = true
            for badgeHost in hosts {
                guard let glyph = badgeHost.glyph, let item = glyph.superview else {
                    glyphDied()
                    return
                }
                badgeHost.capsule.center = TabBadgePlacement.capsuleCenter(glyphCenter: glyph.center,
                                                                           glyphSize: glyphSize)
                // The platter is the ancestor that clips; the item's own frame never does.
                let frameInPlatter = item.convert(badgeHost.capsule.frame, to: platter)
                if !platter.bounds.insetBy(dx: -0.5, dy: -0.5).contains(frameInPlatter) { allFit = false }
            }
            if allFit {
                guard capsuleUnfit else { return }
                // The layout that pushed a capsule past the platter's clip moved back: the overlay re-mounts
                // without a search — the glyphs and their observations never left.
                capsuleUnfit = false
                diagnose("refit")
                remount()
                host(true)
                return
            }
            guard !capsuleUnfit else { return }
            // The platter clips to its bounds, so a capsule its clip would cut (a layout pushing an item to the
            // pane's edge) hands the count to the composite instead of showing it shaved; model geometry is
            // judged, which the morph's presentation-level animation never moves.
            capsuleUnfit = true
            diagnose("fit trip")
            if isHosting {
                host(false)
            } else {
                unmountCapsules(hosts.map(\.capsule))
            }
        }
    }
}

/// One item tree's badge: the glyph the capsule anchors to and the capsule riding beside it. The capsules are
/// pixel-identical twins of the same render, one per parallel item tree, so every tree shows the badge exactly as
/// it shows its glyph.
final class BadgeHost {
    weak var glyph: UIImageView?
    let capsule = TabBadgeCapsuleView()

    init(glyph: UIImageView, onDetach: @escaping () -> Void) {
        self.glyph = glyph
        capsule.isUserInteractionEnabled = false
        // The tab's accessibility value stays the one VoiceOver seam for the count.
        capsule.isAccessibilityElement = false
        capsule.onDetach = onDetach
    }
}

/// The overlay's capsule, which reports losing its window: the one way it leaves outside a deliberate removal is
/// its host item dying, and no observed layer announces that.
final class TabBadgeCapsuleView: UIImageView {
    var onDetach: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { onDetach?() }
    }
}
