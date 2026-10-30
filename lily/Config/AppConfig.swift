import Foundation

/// Central place for non-visual configuration. Grouped by domain; no magic values inline elsewhere.
nonisolated enum AppConfig {
    enum Auth {
        /// Simulated latency of the mock auth service so loading states are visible.
        static let mockSignInDelay: Duration = .milliseconds(900)
        static let minimumPasswordLength = 8
        /// How many bytes of the email digest form a mock user id (kept short for readable logs).
        static let mockUserIDDigestBytes = 8
        /// The code the mock accepts under `-mock-auth-confirm`; the UI tests type it.
        static let mockConfirmationCode = "123456"
        /// Domain of the mock users' email addresses.
        static let mockEmailDomain = "example.com"
    }

    /// The `lily-users` pool and its `lily-ios` client, as rose's `RoseAuthStack` outputs them. Amplify is configured
    /// from these constants in code (`AmplifyConfigurationBuilder`), so no generated JSON file has to ship in the bundle.
    enum Cognito {
        static let region = "eu-central-1"
        static let userPoolId = "eu-central-1_JmfE31ODT"
        static let appClientId = "54dul3essertek166u2st78s4a"
        /// Length of the verification code Cognito emails after sign-up.
        static let confirmationCodeLength = 6
        /// `clientMetadata` key of the app's language on sign-up and resend; rose's Custom Message trigger reads it to
        /// send the code in that language.
        static let localeMetadataKey = "locale"
    }

    enum Storage {
        enum Keys {
            static let storedSession = "lily.session.stored"
            /// The language chosen on Profile: a language code, or `system`.
            static let languagePreference = "lily.language.preference"
            /// Explore's filter as last set (`PersistedEventFilter` as JSON), restored on launch.
            static let eventFilter = "lily.events.filter"
        }
        /// Each preview gets its own `UserDefaults` suite so mock sessions never bleed into the real app.
        static let previewSuitePrefix = "lily.preview."
        /// The stored word for "follow the system", shared by the language and currency choices.
        static let systemChoiceValue = "system"
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
        /// Decimals of the position sent with the upcoming list (about 1 km): enough to order by distance, too coarse to
        /// place the user. The backend rounds to the same precision.
        static let positionPrecision = 2

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

        /// What an edit is held to beyond `Creation`'s limits. The backend requires only the future, so a host fixing
        /// the place of a game that starts in ten minutes is not told to move the start as well.
        enum Editing {
            /// An edit's start must lie this far ahead of the device clock: enough for the round trip and clock skew,
            /// so the backend still sees the future when the request lands and Save never earns its 400.
            static let startMargin: TimeInterval = 60
            /// What a tournament edit needs beyond the future: nothing. `TournamentDraft.Rules.editing` reads it, and
            /// its backend has no future check.
            static let minimumLeadTime: TimeInterval = 0
        }
    }

    /// The one freshness rule of every list that caches a backend answer (the events lists, Mine, the inbox, the
    /// tournament lists), read through `ContentFreshness.standard`.
    enum Lists {
        /// A tab that reappears reuses content loaded more recently than this; pull-to-refresh always reloads.
        static let staleAfter: TimeInterval = 60
        /// A failed load is not retried by a reappearing tab before this has passed, so switching tabs while the
        /// backend is down neither hammers it nor repeats the popup; pull-to-refresh is not held back.
        static let retryAfterFailure: TimeInterval = 10
        /// Where the tabs' lists keep their last answer under `Caches/`, one JSON file per list and caller, for the
        /// first frame of the next launch (`ListSnapshotStore`).
        static let snapshotDirectoryName = "ListSnapshots"
        /// The caller part of a guest's snapshot file name.
        static let guestSnapshotName = "guest"
        /// The lists' names in their snapshot files; a scope reads its own through `snapshotList`.
        static let upcomingEventsSnapshot = "events-upcoming"
        static let joinedEventsSnapshot = "events-joined"
        static let upcomingTournamentsSnapshot = "tournaments-upcoming"
        static let mineTournamentsSnapshot = "tournaments-mine"
        static let mineGroupsSnapshot = "groups-mine"
        static let discoverGroupsSnapshot = "groups-discover"
        /// A group's segments are built when the group opens and keep no snapshot; the name is for the key alone.
        static func groupEventsSnapshot(_ groupID: String) -> String { "events-group-\(groupID)" }
        static func groupTournamentsSnapshot(_ groupID: String) -> String { "tournaments-group-\(groupID)" }
    }

    enum Location {
        /// Demo centre for mock location and fixture events (Berlin, Mitte).
        static let mockCenter = Coordinate(latitude: 52.5200, longitude: 13.4050)
        /// Radius (in degrees) within which fixture events are scattered.
        static let fixtureSpreadDegrees = 0.03
        /// Side of the area the location picker shows when it opens, in metres: a neighbourhood, so one drag lands the pin.
        static let pickerRegionMeters: Double = 1_500
        /// A settle of the picker's map closer than this to the spot already chosen is the map arriving, not a move: the
        /// arrival nudges the pin by centimetres, one point of drag at the picker's span is about four metres.
        static let pickerMinimumMoveMeters: Double = 1
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
        /// The simulator reaches a Laurel on the Mac through its loopback; a phone's loopback is the phone, so a debug
        /// build on a device talks to production like a release build, unless `-api-base-url` names a Laurel to reach.
        #if DEBUG && targetEnvironment(simulator)
        static let baseURL = localBaseURL
        #else
        static let baseURL = productionBaseURL
        #endif
        static let requestTimeout: TimeInterval = 15
        /// Pause before the one automatic repeat of a write the backend answered with `TRY_AGAIN` (a join, a leave,
        /// a group change, an invite or a chat send lost a race with another caller or was throttled by DynamoDB;
        /// the same request very likely succeeds on the next attempt).
        static let tryAgainDelay: Duration = .milliseconds(400)
        /// Debug builds identify the signed-in user to the local backend with `Headers.localUserID` (it runs without
        /// Cognito). Release builds never send it; they will carry a Cognito token instead.
        #if DEBUG
        static let sendsLocalUserHeader = true
        #else
        static let sendsLocalUserHeader = false
        #endif

        /// A rejected or missing token; the backend sends no body with it, so the status alone must be recognised.
        static let unauthorizedStatus = 401
        /// The backend's rate limit; recognised by status too, in case the `{code, message}` body is missing.
        static let rateLimitedStatus = 429
        /// The range of a refusal; a known backend code inside it is an expected product state, not a fault.
        static let clientErrorStatuses = 400..<500

        enum Headers {
            static let localUserID = "X-Local-User-Id"
            /// `<CFBundleShortVersionString> (<CFBundleVersion>)`, e.g. `1.0 (42)`, on every request (`AppVersion`).
            static let appVersion = "X-App-Version"
            static let authorization = "Authorization"
            static let bearerPrefix = "Bearer "
            static let accept = "Accept"
            static let contentType = "Content-Type"
            static let json = "application/json"
        }

        enum Paths {
            static let events = "/api/events"
            static let profile = "/api/profile"
            static let interactions = "/api/interactions"

            static func event(id: String) -> String {
                "\(events)/\(id)"
            }

            static func participants(eventId: String) -> String {
                "\(event(id: eventId))/participants"
            }
        }

        enum Query {
            static let scope = "scope"
            static let latitude = "lat"
            static let longitude = "lon"
        }
    }

    /// Usage statistics a signed-in user's taps produce (`POST /api/interactions`); guests send nothing.
    enum Statistics {
        /// Buffered interactions are sent as soon as this many have gathered.
        static let batchSize = 10
        /// A smaller batch is sent this long after its first interaction.
        static let flushDelay: Duration = .seconds(30)
        /// Beyond this the oldest buffered interaction is dropped: a backend that stays down must not grow memory.
        static let maxBuffered = 100
        /// A sign-out flushes what is buffered while the Bearer still goes out, and waits for it this long at most: a
        /// stalled network must not hold the sign-out (`API.requestTimeout` is 15 s).
        static let signOutFlushTimeout: Duration = .seconds(3)
        /// The most type names a `filter_applied` carries, the backend's `FilterSummaryDto.MAX_TYPES`: a longer list is
        /// a `400 VALIDATION_FAILED` for the whole batch, which the recorder drops without retry, so `EventType.known`
        /// must stay within it.
        static let maxFilterTypes = 32
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
        /// Swaps Cognito for the mock auth service, so UI tests and demos sign in without a pool or a network.
        static let mockAuth = "-mock-auth"
        /// The mock, with sign-up asking for the confirmation code `Auth.mockConfirmationCode`, so the confirm step can be
        /// walked without an email.
        static let mockAuthConfirm = "-mock-auth-confirm"
        /// The mock, with every auth call failing with a network error, so UI tests can check the error popup.
        static let mockAuthFail = "-mock-auth-fail"
        /// Serves the fixture events and accepts profile updates in memory, so UI tests and demos need no backend.
        static let mockEvents = "-mock-events"
        /// With the mock events, the first list load fails with a network error and every later one answers, so the
        /// root error popup and the list's failed state can be walked without a backend.
        static let mockEventsFail = "-mock-events-fail"
        /// Keeps every error popup up until it is dismissed instead of letting it fade after `ErrorPopup.autoDismissDelay`,
        /// so a UI test on a slow runner finds the popup it provoked rather than the place it just left.
        static let holdPopups = "-hold-popups"
        /// Freezes the aurora on its first frame, as Reduce Motion does: the 30 fps mesh and grain keep the simulator's
        /// compositor at two fifths of a core on a Mac and starve a runner that renders in software.
        static let freezeAurora = "-freeze-aurora"
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

    enum Version {
        static let marketingKey = "CFBundleShortVersionString"
        static let buildKey = "CFBundleVersion"
        /// Stands in for a component the bundle does not carry (a test bundle without a host).
        static let unknownComponent = "0"
    }
}
