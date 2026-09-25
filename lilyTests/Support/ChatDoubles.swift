import Foundation
@testable import lily

/// Scriptable `ChatRepository`: pages answer from queues (an empty page once a queue runs dry), sends from `sendErrors`
/// then `makeSent`, and every call is recorded in order. `holdsRequests` parks page requests until released.
@MainActor
final class FakeChatRepository: ChatRepository {
    var epoch = 1
    var newestPages: [MessagePage] = []
    var olderPages: [MessagePage] = []
    var newerPages: [MessagePage] = []
    /// Thrown by the next sends, one each, before a send succeeds.
    var sendErrors: [any Error] = []
    /// Thrown by every page request when set.
    var pageError: (any Error)?
    var deleteError: (any Error)?
    var readMarkerError: (any Error)?
    /// The epoch the next send and read marker answers carry; `epoch` otherwise.
    var responseEpoch: Int?
    var holdsRequests = false
    /// Runs at the start of every request, so a test can look at other collaborators at that moment.
    var onRequest: () -> Void = {}
    private var pending: [CheckedContinuation<Void, Never>] = []
    private(set) var newestGroupIDs: [String] = []
    private(set) var olderRequests: [(groupID: String, before: String)] = []
    private(set) var newerRequests: [(groupID: String, after: String)] = []
    private(set) var sentDrafts: [MessageDraft] = []
    private(set) var deletedMessageIDs: [String] = []
    private(set) var readMarks: [(groupID: String, messageID: String)] = []
    private var sequence = 0

    func newest(groupID: String) async throws -> MessagePage {
        newestGroupIDs.append(groupID)
        return try await page(\.newestPages)
    }

    func older(groupID: String, before messageID: String) async throws -> MessagePage {
        olderRequests.append((groupID, messageID))
        return try await page(\.olderPages)
    }

    func newer(groupID: String, after messageID: String) async throws -> MessagePage {
        newerRequests.append((groupID, messageID))
        return try await page(\.newerPages)
    }

    func send(groupID: String, _ draft: MessageDraft) async throws -> SentMessage {
        onRequest()
        sentDrafts.append(draft)
        await holdIfRequested()
        if !sendErrors.isEmpty { throw sendErrors.removeFirst() }
        sequence += 1
        let message = ChatMessage.fixture(id: "sent-\(sequence)",
                                          groupID: groupID,
                                          senderUserID: TestFixtures.user.id,
                                          text: draft.trimmedText,
                                          clientMessageID: draft.clientMessageID)
        return SentMessage(message: message, channelEpoch: responseEpoch ?? epoch)
    }

    func delete(groupID: String, messageID: String) async throws -> ChatMessage {
        deletedMessageIDs.append(messageID)
        if let deleteError { throw deleteError }
        return ChatMessage.fixture(id: messageID, groupID: groupID).markingDeleted()
    }

    func markRead(groupID: String, messageID: String) async throws -> ReadMarker {
        readMarks.append((groupID, messageID))
        if let readMarkerError { throw readMarkerError }
        return ReadMarker(lastReadMessageId: messageID, channelEpoch: responseEpoch ?? epoch)
    }

    func releaseRequests() {
        holdsRequests = false
        pending.forEach { $0.resume() }
        pending.removeAll()
    }

    private func page(_ queue: ReferenceWritableKeyPath<FakeChatRepository, [MessagePage]>) async throws -> MessagePage {
        onRequest()
        await holdIfRequested()
        if let pageError { throw pageError }
        guard !self[keyPath: queue].isEmpty else { return MessagePage(items: [], hasMore: false, channelEpoch: epoch) }
        return self[keyPath: queue].removeFirst()
    }

    private func holdIfRequested() async {
        if holdsRequests {
            await withCheckedContinuation { pending.append($0) }
        }
    }
}

/// A transport that records what the controller does and lets a test feed envelopes or end streams.
@MainActor
final class FakeRealtimeTransport: RealtimeTransport {
    private struct Subscription {
        let channel: RealtimeChannel
        let continuation: AsyncThrowingStream<RealtimeEnvelope, any Error>.Continuation
    }

    /// Thrown by the next connects, one each.
    var connectErrors: [any Error] = []
    private(set) var connectedEndpoints: [URL] = []
    private(set) var disconnectCount = 0
    /// Every channel ever subscribed, in order.
    private(set) var subscriptionLog: [RealtimeChannel] = []
    private var subscriptions: [UUID: Subscription] = [:]

    var connectCount: Int { connectedEndpoints.count }
    /// The channels with a live stream right now.
    var subscribedChannels: [RealtimeChannel] { subscriptions.values.map(\.channel) }

    func connect(endpoint: URL) async throws {
        if !connectErrors.isEmpty { throw connectErrors.removeFirst() }
        connectedEndpoints.append(endpoint)
    }

    func subscribe(to channel: RealtimeChannel) -> AsyncThrowingStream<RealtimeEnvelope, any Error> {
        let id = UUID()
        let (stream, continuation) = AsyncThrowingStream<RealtimeEnvelope, any Error>.makeStream()
        subscriptions[id] = Subscription(channel: channel, continuation: continuation)
        subscriptionLog.append(channel)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in self?.subscriptions[id] = nil }
        }
        return stream
    }

    func disconnect() async {
        disconnectCount += 1
        let open = subscriptions.values
        subscriptions.removeAll()
        open.forEach { $0.continuation.finish() }
    }

    func post(_ envelope: RealtimeEnvelope, to channel: RealtimeChannel) {
        subscriptions.values.filter { $0.channel == channel }.forEach { $0.continuation.yield(envelope) }
    }

    /// Ends the stream of `channel` the way the library would: refused, or with the connection.
    func finish(_ channel: RealtimeChannel, throwing error: RealtimeTransportError?) {
        for (id, subscription) in subscriptions where subscription.channel == channel {
            subscriptions[id] = nil
            subscription.continuation.finish(throwing: error)
        }
    }
}

@MainActor
final class FakeRealtimeEndpointProvider: RealtimeEndpointProvider {
    var url: URL?
    private(set) var requestCount = 0

    init(url: URL? = URL(string: "https://realtime.test/event")) {
        self.url = url
    }

    func endpoint() async -> URL? {
        requestCount += 1
        return url
    }
}

/// A clock a test moves by hand.
@MainActor
final class DateClock {
    var now: Date

    init(_ now: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        self.now = now
    }

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
