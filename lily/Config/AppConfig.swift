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
        static let mockFeedSize = 9
        /// Fill ratio at which an event is called "nearly full" and highlighted.
        static let nearlyFullRatio = 0.75
        /// Number of upcoming events previewed on the landing screen.
        static let landingPreviewCount = 3
        /// Distance choices in the Explore filter, in metres from the reference point, and the one applied by default.
        static let filterRadiiMeters: [Double] = [2_000, 5_000, 10_000, 25_000]
        static let defaultFilterRadiusMeters: Double = 10_000
        /// Length of the date range the filter proposes when dates are switched on.
        static let defaultFilterDateSpanDays = 7
        /// Currency of every event until the backend carries one per event; fixtures and the price filter use it.
        static let marketCurrencyCode = "EUR"
        /// A tab that reappears reuses events loaded more recently than this; pull-to-refresh always reloads.
        static let listStaleAfter: TimeInterval = 60
        /// A failed load is not retried by a reappearing tab before this has passed, so switching tabs while the
        /// backend is down neither hammers it nor repeats the popup; pull-to-refresh is not held back.
        static let retryAfterFailure: TimeInterval = 10

        /// Limits of the create form, the backend's `CreateEventRequest` constraints mirrored so a draft that passes
        /// here never earns a 400. Text lengths are UTF-16 units, as Java's `String.length()` counts them.
        enum Creation {
            static let titleMaxLength = 80
            static let locationNameMaxLength = 120
            static let descriptionMaxLength = 1000
            static let lookingForMaxLength = 300
            static let capacityRange = 2...200
            static let defaultCapacity = 10
            /// A game must start at least this far in the future; the minutes are what the form's hint names.
            static let minimumLeadTimeMinutes = 15
            static let minimumLeadTime: TimeInterval = TimeInterval(minimumLeadTimeMinutes) * 60
            /// A new draft proposes a start this far ahead, rounded up to the hour.
            static let defaultStartOffset: TimeInterval = 24 * 60 * 60
            /// The backend accepts at most seven integer digits and two decimals for a price.
            static let priceLimitExclusive: Decimal = 10_000_000
            static let priceMinorUnitsPerUnit: Decimal = 100
        }
    }

    enum Location {
        /// Demo centre for mock location and fixture events (Berlin, Mitte).
        static let mockCenter = Coordinate(latitude: 52.5200, longitude: 13.4050)
        /// Radius (in degrees) within which fixture events are scattered.
        static let fixtureSpreadDegrees = 0.03
        /// Side of the area the location picker shows when it opens, in metres: a neighbourhood, so one drag lands the pin.
        static let pickerRegionMeters: Double = 1_500
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
        /// Plain HTTP needs no ATS exception here: ATS exempts unqualified host names.
        static let localBaseURL = URL(string: "http://localhost:8080")!
        static let productionBaseURL = URL(string: "https://api.iskra.red")!
        #if DEBUG
        static let baseURL = localBaseURL
        #else
        static let baseURL = productionBaseURL
        #endif
        static let requestTimeout: TimeInterval = 15
        /// Pause before the one automatic repeat of a join or leave the backend answered with `TRY_AGAIN` (the
        /// write lost a race with another player or was throttled by DynamoDB; the same request very likely
        /// succeeds on the next attempt).
        static let tryAgainDelay: Duration = .milliseconds(400)
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

            static func event(id: String) -> String {
                "\(events)/\(id)"
            }

            static func participants(eventId: String) -> String {
                "\(event(id: eventId))/participants"
            }
        }

        enum Query {
            static let scope = "scope"
        }
    }

    /// Process arguments recognised at launch (used by UI tests). Debug builds only: `AppDependencies` reads them
    /// when `isHonored` is true, so a release build cannot be started as a guest or on mock data from the outside.
    enum LaunchArguments {
        #if DEBUG
        static let isHonored = true
        #else
        static let isHonored = false
        #endif
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
        /// Takes the next argument as its value, e.g. `-api-base-url http://<mac-name>.local:8080`.
        static let apiBaseURL = "-api-base-url"
        /// An argument with this prefix is a flag, never a value.
        static let flagPrefix = "-"

        /// The argument after `flag`; `nil` when the flag is missing, last, or followed by another flag.
        static func value(following flag: String, in arguments: [String]) -> String? {
            guard let index = arguments.firstIndex(of: flag) else { return nil }
            let next = arguments.index(after: index)
            guard next < arguments.endIndex, !arguments[next].hasPrefix(flagPrefix) else { return nil }
            return arguments[next]
        }
    }

    enum Logging {
        static let subsystem = Bundle.main.bundleIdentifier ?? "iris.lily"
    }
}
