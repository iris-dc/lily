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
        /// Fill ratio at which an event is called "nearly full" and highlighted.
        static let nearlyFullRatio = 0.75
        /// Number of upcoming events previewed on the landing screen.
        static let landingPreviewCount = 3
        /// A tab that reappears reuses events loaded more recently than this; pull-to-refresh always reloads.
        static let listStaleAfter: TimeInterval = 60
    }

    enum Location {
        /// Demo centre for mock location and fixture events (Berlin, Mitte).
        static let mockCenter = Coordinate(latitude: 52.5200, longitude: 13.4050)
        /// Radius (in degrees) within which fixture events are scattered.
        static let fixtureSpreadDegrees = 0.03
        /// Waiting longer than this for a GPS fix falls back to a map centred on the events.
        static let fixTimeout: Duration = .seconds(8)
        /// A fix is reused for this long, so screens re-appearing and sibling tabs share one CoreLocation stream.
        static let fixTTL: Duration = .seconds(300)
        /// A missing fix (denied or timed out) is remembered this long: short, so a later GPS fix is picked up soon.
        static let failedFixTTL: Duration = .seconds(30)
    }

    enum ErrorPopup {
        static let autoDismissDelay: Duration = .seconds(4)
    }

    /// The Laurel backend. Paths are relative to `baseURL`; the request shapes are documented in the README.
    enum API {
        /// Local Laurel instance. The simulator shares the host's loopback, so `localhost` reaches it directly
        /// (ATS exempts unqualified host names, so plain HTTP needs no Info.plist exception).
        static let baseURL = URL(string: "http://localhost:8080")!
        static let requestTimeout: TimeInterval = 15
        /// Debug builds identify the signed-in user to the local backend with `Headers.localUserID` (it runs without
        /// Cognito). Release builds never send it; they will carry a Cognito token instead.
        #if DEBUG
        static let sendsLocalUserHeader = true
        #else
        static let sendsLocalUserHeader = false
        #endif

        enum Headers {
            static let localUserID = "X-Local-User-Id"
            static let accept = "Accept"
            static let contentType = "Content-Type"
            static let json = "application/json"
        }

        enum Paths {
            static let events = "/api/events"
            static let profile = "/api/profile"

            static func participants(eventId: String) -> String {
                "\(events)/\(eventId)/participants"
            }
        }

        enum Query {
            static let scope = "scope"
        }
    }

    /// Process arguments recognised at launch (used by UI tests).
    enum LaunchArguments {
        /// Clears any stored session so the app starts on the welcome screen.
        static let resetSession = "-reset-session"
        /// Uses the mock location service so UI tests never hit the system permission prompt.
        static let mockLocation = "-mock-location"
        /// Starts inside the app as a guest (after any reset), so UI tests and screenshots skip the landing.
        static let startAsGuest = "-start-as-guest"
        /// Makes every mock auth call fail with a network error, so UI tests can check the error popup.
        static let mockAuthFail = "-mock-auth-fail"
        /// Serves the fixture events and accepts profile updates in memory, so UI tests and demos need no backend.
        static let mockEvents = "-mock-events"
    }

    enum Logging {
        static let subsystem = Bundle.main.bundleIdentifier ?? "iris.lily"
    }
}
