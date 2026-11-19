import SwiftUI
import UIKit

/// The rule telling the iOS 26 floating bar's minimized state from its panes. The bar's expanded platter spans about
/// three quarters of the bar, the minimized circle about an eighth, so the midpoint tells them apart on every phone
/// width with no pixel constant; while both show (mid-swap) the bar reads as expanded, so the badge errs on showing.
/// A pane before its first layout reports zero width: no laid-out visible pane is no signal, and the answer is
/// expanded — a wrong "minimized" would hide the badge with no later KVO event to correct it.
enum TabBarCollapse {
    static func isMinimized(visiblePaneWidths: [CGFloat], barWidth: CGFloat) -> Bool {
        guard barWidth > 0, let widest = visiblePaneWidths.max(), widest > 0 else { return false }
        return widest < barWidth / 2
    }
}

/// Reports the floating tab bar's minimized state to SwiftUI, so `MainTabView` can hide the drawn Chats badge while
/// the bar is one small circle (the circle draws the tab's `UIImage` unscaled, and the owner-tuned badge pokes past
/// its rim). No supported seam says "minimized": `tabBarMinimizeBehavior` has no readable state or callback, and the
/// tab-accessory traits apply only inside a bottom accessory. So this reads the bar's own views — SwiftUI's `TabView`
/// is backed by a real `UITabBar` holding one pane per state, swapped by visibility — through KVO on the panes'
/// layers (`CALayer` is KVO-compliant where `UIView` is not), re-attached when the bar swaps its pane set; no
/// polling. Fragile by nature: only the `UITabBar` class is public, the pane shapes are observed behaviour, not API.
/// When the hierarchy changes and the signal is lost, nothing reports and the badge simply stays visible — the
/// accepted fallback (it may poke past the minimized circle again, never stick hidden). On the iPad the tabs are a
/// top bar that never minimizes and has no `UITabBar`, so the reporter finds nothing and stays silent.
struct TabBarMinimizeReporter: UIViewRepresentable {
    let onChange: (Bool) -> Void

    func makeUIView(context: Context) -> ReporterView { ReporterView() }

    func updateUIView(_ view: ReporterView, context: Context) {
        view.onChange = onChange
    }

    final class ReporterView: UIView {
        var onChange: ((Bool) -> Void)?
        private weak var bar: UITabBar?
        private var observations: [NSKeyValueObservation] = []
        /// The observed panes by identity, so a sublayer churn re-attaches only when the pane set itself changed.
        private var observedPanes: [ObjectIdentifier] = []
        private var isMinimized = false
        private var findBudget = 0

        override func didMoveToWindow() {
            super.didMoveToWindow()
            findBudget = AppConfig.Shell.tabBarFindAttempts
            attach()
        }

        /// Finds the bar and observes its panes; observing the bar's own sublayers catches a pane UIKit re-creates.
        private func attach() {
            observations.removeAll()
            observedPanes = []
            bar = window.flatMap { Self.findTabBar(in: $0) }
            guard let bar else {
                scheduleRetry()
                return
            }
            observations.append(bar.layer.observe(\.sublayers) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.panesDidChurn() }
            })
            observedPanes = bar.subviews.map(ObjectIdentifier.init)
            for pane in bar.subviews {
                observations.append(pane.layer.observe(\.isHidden) { [weak self] _, _ in
                    Task { @MainActor [weak self] in self?.report() }
                })
                observations.append(pane.layer.observe(\.opacity) { [weak self] _, _ in
                    Task { @MainActor [weak self] in self?.report() }
                })
            }
            report()
        }

        /// Re-attaches only when the pane set itself changed (UIKit re-created one): the bar's layer churns on every
        /// state swap, and a full tear-down per churn would re-create every observation for nothing; a same-set churn
        /// only re-reads the state.
        private func panesDidChurn() {
            guard let bar else { return }
            if bar.subviews.map(ObjectIdentifier.init) == observedPanes {
                report()
            } else {
                attach()
            }
        }

        /// The bar joins the window a few frames after this view does (SwiftUI adds its UIKit backing separately),
        /// so a failed find retries on short deferrals; the budget ends the search, so it never becomes polling.
        private func scheduleRetry() {
            guard window != nil, findBudget > 0 else { return }
            findBudget -= 1
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.Shell.tabBarFindRetryDelay) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, self.bar == nil else { return }
                    self.attach()
                }
            }
        }

        private func report() {
            guard let bar else { return }
            let widths = bar.subviews
                .filter { !$0.isHidden && $0.alpha > DesignTokens.TabBar.paneVisibleAlpha }
                .map { $0.bounds.width }
            let minimized = TabBarCollapse.isMinimized(visiblePaneWidths: widths, barWidth: bar.bounds.width)
            guard minimized != isMinimized else { return }
            isMinimized = minimized
            // Deferred: KVO can fire inside a UIKit layout pass, and the handler writes SwiftUI state.
            let tell = onChange
            DispatchQueue.main.async { tell?(minimized) }
        }

        private static func findTabBar(in root: UIView) -> UITabBar? {
            var queue: [UIView] = [root]
            var index = 0
            while index < queue.count {
                let view = queue[index]
                index += 1
                if let found = view as? UITabBar { return found }
                queue.append(contentsOf: view.subviews)
            }
            return nil
        }
    }
}
