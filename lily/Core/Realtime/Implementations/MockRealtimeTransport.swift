import Foundation

/// An in-memory bus standing in for the realtime API: the mock repositories `post` what the backend would publish,
/// and every live subscription to that channel receives it. Connects anywhere, refuses nothing.
final class MockRealtimeTransport: RealtimeTransport {
    private struct Subscription {
        let channel: RealtimeChannel
        let continuation: AsyncThrowingStream<RealtimeEnvelope, any Error>.Continuation
    }

    private var subscriptions: [UUID: Subscription] = [:]
    private(set) var isConnected = false
    private let logger: any Logging

    init(logger: any Logging) {
        self.logger = logger
    }

    /// The channels with a live subscription, for tests and the debug log.
    var subscribedChannels: [RealtimeChannel] { subscriptions.values.map(\.channel) }

    func connect(endpoint: URL) async throws {
        isConnected = true
        logger.debug(.chat, "Mock realtime connected")
    }

    func subscribe(to channel: RealtimeChannel) -> AsyncThrowingStream<RealtimeEnvelope, any Error> {
        let id = UUID()
        let (stream, continuation) = AsyncThrowingStream<RealtimeEnvelope, any Error>.makeStream()
        subscriptions[id] = Subscription(channel: channel, continuation: continuation)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in self?.subscriptions[id] = nil }
        }
        return stream
    }

    func disconnect() async {
        isConnected = false
        let open = subscriptions.values
        subscriptions.removeAll()
        open.forEach { $0.continuation.finish() }
        logger.debug(.chat, "Mock realtime disconnected")
    }

    /// Delivers to every subscriber of `channel`; nobody listening is fine.
    func post(_ envelope: RealtimeEnvelope, to channel: RealtimeChannel) {
        subscriptions.values.filter { $0.channel == channel }.forEach { $0.continuation.yield(envelope) }
    }
}
