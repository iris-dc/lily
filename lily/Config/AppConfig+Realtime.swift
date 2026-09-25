import Foundation

nonisolated extension AppConfig {
    /// The realtime connection (AppSync Events): channel names, reconnect timing and the room subscription budget.
    enum Realtime {
        /// The `RoseRealtimeStack` output `EventApiHttpEndpoint`; used when `GET /api/me` names none. Stays `nil`
        /// until that stack is deployed, and always in debug builds, where the `-realtime-endpoint` argument decides.
        static let productionEndpoint: URL? = nil
        /// A connection is renewed this long before its token expires.
        static let reconnectBeforeExpiry: TimeInterval = 300
        static let maxConnectionAge: TimeInterval = 21_600
        static let reconnectBackoffSeconds: [TimeInterval] = [1, 2, 4, 8, 16, 30]
        static let reconnectJitter = 0.2
        /// Rooms kept subscribed besides the open one: the most recently active groups.
        static let maxRoomSubscriptions = 10
        /// An epoch change makes every member resubscribe; each waits this much per member, capped, so they do not herd.
        static let resubscribeJitterPerMember: TimeInterval = 0.01
        static let resubscribeJitterMax: TimeInterval = 5
        static let roomsNamespace = "rooms"
        static let usersNamespace = "users"
        /// What the mock endpoint provider answers; the in-memory transport never connects anywhere.
        static let mockEndpoint = URL(string: "mock://realtime")!
    }
}

nonisolated extension AppConfig.LaunchArguments {
    /// Takes the next argument as the realtime endpoint URL, for a debug build against a deployed AppSync API.
    static let realtimeEndpoint = "-realtime-endpoint"
}
