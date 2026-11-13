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
        /// A forced token refresh that answers nil (`CognitoAuthService.token` swallows every error, a lost network
        /// included) is retried this many times along `reconnectBackoffSeconds` (its six entries, then the last twice:
        /// about two minutes) before the connection waits for the next foreground.
        static let maxReconnectsWithoutToken = 8
        /// Rooms kept subscribed besides the open one: the most recently active groups.
        static let maxRoomSubscriptions = 10
        /// An epoch change makes every member resubscribe; each waits this much per member, capped, so they do not herd.
        static let resubscribeJitterPerMember: TimeInterval = 0.01
        static let resubscribeJitterMax: TimeInterval = 5
        static let roomsNamespace = "rooms"
        static let usersNamespace = "users"
        /// What the mock endpoint provider answers; the in-memory transport never connects anywhere.
        static let mockEndpoint = URL(string: "mock://realtime")!
        /// How long a connect waits for the server's `connection_ack` before giving up as a lost connection.
        static let connectTimeout: TimeInterval = 15
        /// The keep-alive window when the ack names none; the server names five minutes today.
        static let defaultKeepAliveTimeout: TimeInterval = 300
        /// A subscribe whose server-side membership check failed is retried along `reconnectBackoffSeconds` this many
        /// times before its stream gives the connection up.
        static let subscribeRetryLimit = 6
        /// The `subscribe_error` type retried with backoff: the backend's handlers answer it when their read failed.
        static let retriedSubscribeError = "SubscriptionCheckFailed"
        /// The `subscribe_error` family that means the caller may not have the channel (a stale epoch, not a member).
        static let unauthorizedSubscribeError = "Unauthorized"
        /// The WebSocket upgrade carries the protocol name and the base64url authorization in this header.
        static let subprotocolHeaderField = "Sec-WebSocket-Protocol"
        static let subprotocolName = "aws-appsync-event-ws"
        static let subprotocolHeaderPrefix = "header-"
        /// An AWS-domain endpoint derives its socket host by swapping these fragments; a custom domain keeps its own.
        static let awsDomainSuffix = "amazonaws.com"
        static let httpHostFragment = "appsync-api"
        static let socketHostFragment = "appsync-realtime-api"
        static let socketScheme = "wss"
        static let socketPath = "/event/realtime"
        /// What a WebSocket upgrade answers when it succeeds; any other status on the task is a refusal.
        static let switchingProtocolsStatus = 101
    }
}

nonisolated extension AppConfig.LaunchArguments {
    /// Takes the next argument as the realtime endpoint URL, for a debug build against a deployed AppSync API.
    static let realtimeEndpoint = "-realtime-endpoint"
}
