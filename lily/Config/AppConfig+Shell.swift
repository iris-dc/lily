import CoreGraphics
import Foundation

nonisolated extension AppConfig {
    /// The shell's tab bar, read by `TabBarBareCircle`.
    enum Shell {
        /// The bar joins the window a few frames after the guard's view (SwiftUI adds its UIKit backing
        /// separately), and the minimized circle only exists after the first minimize: a failed find retries on
        /// short deferrals and the budget ends the search (never steady-state polling). A pane churn re-runs
        /// the full search with a fresh budget once a bar is observed; a guard whose adopted bar died is
        /// re-armed by the SwiftUI update instead — no observation outlives its hierarchy.
        static let tabBarFindAttempts = 20
        static let tabBarFindRetryDelay: TimeInterval = 0.1
        /// Only a pane as narrow as the minimized circle (48 pt; headroom, not a tight pin) may have its mirrored
        /// composite swapped: the expanded platter (which scales with the bar) and the ~100 pt tab-switch
        /// transient never qualify, and the collapse morph animates presentation only, so a pane's model width
        /// never dips through this bound on the way down.
        static let tabBarCircleMaxWidth: CGFloat = 64
        /// Below this alpha an ancestor reads as hiding the circle's mirror: the condemnation walk's floor
        /// (`TabBarBareCircle.isDrawable`) — a stale subtree keeps clean own-flags while an ancestor hides it.
        static let tabBarDrawableAlphaMinimum: CGFloat = 0.01
    }
}
