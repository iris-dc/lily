import Foundation

/// One page of a room's history, ascending by id. `hasMore` points the way the page was asked for: older for `newest`
/// and `before`, newer for `after`. The epoch travels on every group-scoped answer so a lost `member_left` still
/// reaches the room (any epoch that differs from the subscribed one means resubscribe).
nonisolated struct MessagePage: Hashable, Codable, Sendable {
    let items: [ChatMessage]
    let hasMore: Bool
    let channelEpoch: Int
}

/// Answer of `POST /api/groups/{id}/messages`.
nonisolated struct SentMessage: Hashable, Codable, Sendable {
    let message: ChatMessage
    let channelEpoch: Int
}

/// Answer of `PUT /api/groups/{id}/read`; the marker is monotonic, so an older id leaves it where it was.
nonisolated struct ReadMarker: Hashable, Codable, Sendable {
    let lastReadMessageId: String?
    let channelEpoch: Int
}

/// Body of `POST /api/groups/{id}/messages`.
nonisolated struct SendMessagePayload: Encodable, Equatable, Sendable {
    let clientMessageId: String
    let text: String
}

/// Body of `PUT /api/groups/{id}/read`.
nonisolated struct ReadMarkerPayload: Encodable, Equatable, Sendable {
    let messageId: String
}
