import Foundation

nonisolated extension AppConfig {
    /// The shell's tab bar, read by `TabBarMinimizeReporter`.
    enum Shell {
        /// The bar joins the window a few frames after the reporter's view (SwiftUI adds its UIKit backing
        /// separately), so a failed find retries on short deferrals; the budget ends the search, so it never
        /// becomes polling.
        static let tabBarFindAttempts = 20
        static let tabBarFindRetryDelay: TimeInterval = 0.1
    }
}
