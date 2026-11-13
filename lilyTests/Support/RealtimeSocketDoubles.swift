import Foundation
import Testing
@testable import lily

/// A socket the transport's protocol logic is tested over: records the open request and every sent frame, feeds
/// frames in, and fails the stream the way a refused upgrade or a dropped connection would.
@MainActor
final class FakeEventsSocket: EventsSocket {
    private(set) var openRequests: [URLRequest] = []
    private(set) var sentFrames: [String] = []
    private(set) var closeCount = 0
    /// Thrown by the next sends, one each.
    var sendErrors: [any Error] = []
    /// What the next open's stream fails with at once, as a refused handshake does.
    var openFailure: (any Error)?
    private var continuation: AsyncThrowingStream<String, any Error>.Continuation?

    func open(request: URLRequest) -> AsyncThrowingStream<String, any Error> {
        openRequests.append(request)
        let (stream, continuation) = AsyncThrowingStream<String, any Error>.makeStream()
        if let openFailure {
            continuation.finish(throwing: openFailure)
            self.openFailure = nil
        } else {
            self.continuation = continuation
        }
        return stream
    }

    func send(_ text: String) async throws {
        sentFrames.append(text)
        if !sendErrors.isEmpty { throw sendErrors.removeFirst() }
    }

    func close() async {
        closeCount += 1
        continuation?.finish()
        continuation = nil
    }

    /// Feeds one frame into the open stream.
    func feed(_ frame: [String: Any]) {
        continuation?.yield(Self.json(frame))
    }

    /// Ends the stream the way a dropped connection does.
    func fail(_ error: any Error) {
        continuation?.finish(throwing: error)
        continuation = nil
    }

    /// The types sent, in order.
    var sentTypes: [String] {
        sentFrames.compactMap { Self.object($0)?["type"] as? String }
    }

    /// The sent frames of one type, decoded.
    func sent(ofType type: String) -> [[String: Any]] {
        sentFrames.compactMap(Self.object).filter { $0["type"] as? String == type }
    }

    static func json(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(bytes: data, encoding: .utf8) else { return "{}" }
        return text
    }

    private static func object(_ text: String) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any]
    }
}

/// The transport over the fake socket, scripted tokens, a held sleep and jitter pinned to the top of its range.
@MainActor
final class AppSyncTransportHarness {
    let socket = FakeEventsSocket()
    let tokens = FakeAuthTokenProvider(token: "token-1")
    let logger = SpyLogger()
    let sleep = HeldSleep()
    let transport: AppSyncRealtimeTransport
    let endpoint = URL(string: "https://abc.appsync-api.eu-central-1.amazonaws.com/event")!

    init() {
        let sleep = self.sleep
        transport = AppSyncRealtimeTransport(socket: socket,
                                             tokenProvider: tokens,
                                             logger: logger,
                                             sleep: { try await sleep.sleep(for: $0) },
                                             random: { $0.upperBound })
    }

    /// Connects and acknowledges.
    func connect() async throws {
        let task = Task { try await transport.connect(endpoint: endpoint) }
        await settle(until: { socket.sentTypes.contains("connection_init") })
        socket.feed(["type": "connection_ack", "payload": ["connectionTimeoutMs": 300_000]])
        try await task.value
    }

    /// Subscribes and answers the frame id the subscribe went out under.
    func subscribe(to channel: RealtimeChannel) async -> (reader: EnvelopeStreamReader, id: String) {
        let before = socket.sent(ofType: "subscribe").count
        let reader = EnvelopeStreamReader(transport.subscribe(to: channel))
        await settle(until: { socket.sent(ofType: "subscribe").count == before + 1 })
        let id = socket.sent(ofType: "subscribe").last?["id"] as? String ?? ""
        return (reader, id)
    }

    /// The authorization carried in a handshake's subprotocol header.
    static func authorization(inHandshake header: String) -> [String: String]? {
        guard let encoded = header.components(separatedBy: "header-").last else { return nil }
        var base64 = encoded.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }
}

/// Reads one subscription stream and records what it carried and how it ended.
@MainActor
final class EnvelopeStreamReader {
    private(set) var received: [RealtimeEnvelope] = []
    /// Set once the stream ends: the transport error it threw, or `nil` for a plain finish.
    private(set) var outcome: RealtimeTransportError??
    private var task: Task<Void, Never>?

    var hasEnded: Bool { outcome != nil }

    init(_ stream: AsyncThrowingStream<RealtimeEnvelope, any Error>) {
        task = Task { [weak self] in
            do {
                for try await envelope in stream { self?.received.append(envelope) }
                self?.outcome = .some(nil)
            } catch {
                self?.outcome = .some(error as? RealtimeTransportError)
            }
        }
    }

    func cancel() {
        task?.cancel()
    }
}
