import Foundation

/// The real socket: one `URLSessionWebSocketTask` at a time over an ephemeral session. A refused upgrade is told by
/// the task's HTTP response (never 101 Switching Protocols) and surfaces as `EventsSocketFailure.handshakeRefused`.
final class URLSessionEventsSocket: EventsSocket {
    private let session = URLSession(configuration: .ephemeral)
    private var task: URLSessionWebSocketTask?
    private var reader: Task<Void, Never>?

    func open(request: URLRequest) -> AsyncThrowingStream<String, any Error> {
        reader?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        let task = session.webSocketTask(with: request)
        self.task = task
        task.resume()
        let (stream, continuation) = AsyncThrowingStream<String, any Error>.makeStream()
        reader = Task {
            while !Task.isCancelled {
                do {
                    if case .string(let text) = try await task.receive() {
                        continuation.yield(text)
                    }
                } catch {
                    continuation.finish(throwing: Self.failure(of: task, fallback: error))
                    return
                }
            }
            continuation.finish()
        }
        return stream
    }

    func send(_ text: String) async throws {
        guard let task else { throw EventsSocketFailure.notConnected }
        do {
            try await task.send(.string(text))
        } catch {
            throw Self.failure(of: task, fallback: error)
        }
    }

    func close() async {
        reader?.cancel()
        reader = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    /// An upgrade the server answered with an HTTP status carries it on the task; anything else passes through.
    nonisolated private static func failure(of task: URLSessionWebSocketTask, fallback: any Error) -> any Error {
        if let response = task.response as? HTTPURLResponse,
           response.statusCode != AppConfig.Realtime.switchingProtocolsStatus {
            return EventsSocketFailure.handshakeRefused(status: response.statusCode)
        }
        return fallback
    }
}
