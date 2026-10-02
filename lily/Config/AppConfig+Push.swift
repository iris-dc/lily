import Foundation

nonisolated extension AppConfig {
    /// Push notifications: the device registration with the backend and the payload the backend sends.
    enum Push {
        /// A registration older than this is repeated on the next sync, so a token the system rotated reaches the backend;
        /// an unchanged, younger one costs no request.
        static let reregisterInterval: TimeInterval = 24 * 60 * 60
        /// How long the registrar waits for the system to answer `registerForRemoteNotifications` before giving up.
        static let tokenTimeout: Duration = .seconds(10)
        /// How long a sign-out waits for the device to be unregistered before it goes on without it.
        static let unregisterTimeout: Duration = .seconds(3)
        /// The platform the backend keys a registration by.
        static let platform = "ios"
        /// `UserDefaults` key of the last registration (token, user, date), so a launch skips an unchanged one.
        static let lastRegistrationKey = "push.lastRegistration"
        /// The token the mock registrar answers: 64 hex characters, like a real one.
        static let mockToken = String(repeating: "ab", count: 32)

        /// Keys of the notification payload, as Laurel's `ReminderPush` writes them beside `aps`.
        enum Payload {
            static let kind = "kind"
            static let eventID = "eventId"
            static let eventReminder = "event_reminder"
        }
    }
}

nonisolated extension AppConfig.LaunchArguments {
    /// With `-mock-events`, keeps the system's permission prompt and device token instead of the mock registrar, so a
    /// developer can see the prompt and a `simctl push` banner on a simulator without a backend.
    static let systemPush = "-system-push"
}

nonisolated extension AppConfig.API.Paths {
    static let devices = "/api/me/devices"

    static func device(token: String) -> String {
        "\(devices)/\(token)"
    }
}
