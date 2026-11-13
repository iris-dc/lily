import Foundation

/// What the socket fails with besides errors passed through: the server answered the WebSocket upgrade with an HTTP
/// status instead of switching protocols (a refused token, or the kill switch flipping connection auth to IAM-only),
/// or a frame was sent with no socket open. The transport maps the status to its `RealtimeTransportError`.
nonisolated enum EventsSocketFailure: Error, Hashable, Sendable {
    case handshakeRefused(status: Int)
    case notConnected
}
