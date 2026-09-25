import Foundation

nonisolated enum RealtimeConnectionState: Hashable, Sendable {
    /// No endpoint is known, or the transport cannot connect: chat catches up over REST only.
    case unavailable
    case disconnected
    case connecting
    case connected
}
