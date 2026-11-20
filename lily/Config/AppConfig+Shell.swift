import CoreGraphics
import Foundation

nonisolated extension AppConfig {
    /// The shell's tab bar, read by `TabBarBadgeOverlay`.
    enum Shell {
        /// The bar joins the window a few frames after the overlay's view (SwiftUI adds its UIKit backing
        /// separately), so a failed find retries on short deferrals; the budget ends the search, so it never
        /// becomes polling. A hierarchy churn starts a fresh search with the whole budget again.
        static let tabBarFindAttempts = 20
        static let tabBarFindRetryDelay: TimeInterval = 0.1
        /// The expanded platter is the one pane that scales with the bar (about three quarters of it on every
        /// device), so the pane trusted to host the capsule must span at least half the bar
        /// (`TabBadgePlacement.isPlatter`); the minimized circle (48 pt), the ~100 pt tab-switch transient and a
        /// pre-layout zero-width pane never qualify.
        static let tabBarPlatterMinimumFraction: CGFloat = 0.5
        /// How long the expand's morph-direction memory may stand while both panes stay visible: the expand
        /// settles in about 0.7 s, so this grace only ever fires on an abandoned or reversed morph — handing the
        /// badge back to the riding capsule instead of ghosting a static twin over a moving pane.
        static let twinExpandMemoryGrace: TimeInterval = 1.0
    }
}
