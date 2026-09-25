import Foundation

/// The transport of a build without a realtime client: it never connects and every stream ends at once, so the
/// controller stays `.unavailable` and chat catches up over REST.
final class NoRealtimeTransport: RealtimeTransport {
    func connect(endpoint: URL) async throws {
        throw RealtimeTransportError.unavailable
    }

    func subscribe(to channel: RealtimeChannel) -> AsyncThrowingStream<RealtimeEnvelope, any Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func disconnect() async {}
}
