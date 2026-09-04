import Foundation

/// Central place for non-visual configuration. Grouped by domain; no magic values inline elsewhere.
nonisolated enum AppConfig {
    enum Auth {
        /// Simulated latency of the mock auth service so loading states are visible.
        static let mockSignInDelay: Duration = .milliseconds(900)
        static let minimumPasswordLength = 8
        /// How many bytes of the email digest form a mock user id (kept short for readable logs).
        static let mockUserIDDigestBytes = 8
    }

    enum Storage {
        enum Keys {
            static let storedSession = "lily.session.stored"
        }
        /// Each preview gets its own `UserDefaults` suite so mock sessions never bleed into the real app.
        static let previewSuitePrefix = "lily.preview."
    }

    enum Events {
        static let mockFeedSize = 8
    }

    enum ErrorPopup {
        static let autoDismissDelay: Duration = .seconds(4)
    }

    enum Logging {
        static let subsystem = Bundle.main.bundleIdentifier ?? "iris.lily"
    }
}
