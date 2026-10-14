import Foundation

/// The socket to the realtime API. Nothing flows up it: every write is REST, the socket carries only what the backend
/// committed. One connection; a subscription is a stream that ends when the channel is refused (`subscribeRefused`),
/// the connection drops (`connectionLost`) or the consumer stops reading.
protocol RealtimeTransport {
    /// Throws `RealtimeTransportError.unauthorized` when the token is refused and `.unavailable` when this transport
    /// never connects; anything else is a transient failure worth a backoff. Must honour cancellation (throw
    /// `CancellationError` promptly): `close()` cancels a connect in flight and every later connect waits for it.
    /// The token is read from the `AuthTokenProvider` afresh here and on every subscribe; the controller refreshes it
    /// before each reconnect, so the read sees the fresh one. A handshake that completes after the cancellation is
    /// tolerated: the controller disconnects what it opened.
    func connect(endpoint: URL) async throws
    func subscribe(to channel: RealtimeChannel) -> AsyncThrowingStream<RealtimeEnvelope, any Error>
    /// Ends every subscription and closes the connection. Idempotent, and safe during an in-flight `connect` (it must
    /// then close what the handshake still opens, or make that connect throw): the controller calls it twice for one
    /// socket when a `close()` lands mid-handshake.
    func disconnect() async
}
