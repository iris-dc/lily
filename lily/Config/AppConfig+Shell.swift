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
        /// How long a hosted churn's failed re-resolve (an eviction, a glyph death, a dead-host hierarchy
        /// churn) may keep retrying before handing the count to the composite: the device rebuilds the selected
        /// item non-atomically, so the first re-resolves can meet half-built trees, and a composite hand-off
        /// would visibly crossfade through the rebuilding item. A deadline, not a retry count — the rebuild's own
        /// churns re-attach far faster than the retry timer and would burn a counted grace in a millisecond.
        /// Ordinary stand-downs hand off at once.
        static let tabBarHandoffGraceSeconds: TimeInterval = 0.3
        /// Below this alpha a view reads as not drawn: the overlay's drawable walk treats an ancestor at
        /// effectively zero alpha like a hidden one — the select's re-stack hides the stale tree one level
        /// below the observed pane layers while every own-flag stays clean.
        static let tabBarDrawableAlphaMinimum: CGFloat = 0.01
    }
}
