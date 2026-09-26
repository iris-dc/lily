import Foundation

/// The socket to the realtime API. Nothing flows up it: every write is REST, the socket carries only what the backend
/// committed. One connection; a subscription is a stream that ends when the channel is refused (`subscribeRefused`),
/// the connection drops (`connectionLost`) or the consumer stops reading.
protocol RealtimeTransport {
    /// Throws `RealtimeTransportError.unauthorized` when the token is refused and `.unavailable` when this transport
    /// never connects; anything else is a transient failure worth a backoff. Must honour cancellation (throw
    /// `CancellationError` promptly): `close()` cancels a connect in flight and every later connect waits for it.
    func connect(endpoint: URL) async throws
    func subscribe(to channel: RealtimeChannel) -> AsyncThrowingStream<RealtimeEnvelope, any Error>
    /// Ends every subscription and closes the connection.
    func disconnect() async
}
