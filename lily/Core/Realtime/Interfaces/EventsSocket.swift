import Foundation

/// The raw WebSocket under the AppSync transport: one open socket at a time, text frames both ways. A seam, so the
/// transport's protocol logic is unit-tested over a fake; the upgrade request arrives prepared (URL and subprotocol
/// header), and the socket only performs it.
protocol EventsSocket {
    /// Opens the socket and answers the incoming text frames. A refused upgrade (the server answered an HTTP status
    /// instead of switching protocols) fails the stream, or the next `send`, with
    /// `EventsSocketFailure.handshakeRefused(status:)`; a dropped connection fails it with the underlying error as is.
    func open(request: URLRequest) -> AsyncThrowingStream<String, any Error>
    /// Sends one text frame; throws when the socket is not open or the send failed.
    func send(_ text: String) async throws
    /// Closes the socket and ends the open stream. Idempotent.
    func close() async
}
