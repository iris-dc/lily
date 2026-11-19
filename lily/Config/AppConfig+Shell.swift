import CoreGraphics
import Foundation

nonisolated extension AppConfig {
    /// The shell's tab bar, read by `TabBarBadgeOverlay` and `TabBarCollapse`.
    enum Shell {
        /// The bar joins the window a few frames after the overlay's view (SwiftUI adds its UIKit backing
        /// separately), so a failed find retries on short deferrals; the budget ends the search, so it never
        /// becomes polling. A hierarchy churn starts a fresh search with the whole budget again.
        static let tabBarFindAttempts = 20
        static let tabBarFindRetryDelay: TimeInterval = 0.1
        /// The bar's small panes are absolute sizes on every device — the minimized circle measures 48 pt and the
        /// tab-switch transient pane about 100 pt — so the circle bound is absolute, between the two with margin
        /// both ways; a width-relative bound (a quarter of the bar) crossed the transient on 400 pt-class bars
        /// and read every tab switch as a collapse morph.
        static let tabBarCircleMaxWidth: CGFloat = 72
        /// The expanded platter is the one pane that scales with the bar (about three quarters of it on every
        /// device), so its bound stays a fraction: at least half the bar is the platter.
        static let tabBarPlatterMinimumFraction: CGFloat = 0.5
    }
}
