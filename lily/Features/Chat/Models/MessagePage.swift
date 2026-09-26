import Foundation

/// One page of a room's history, ascending by id. `hasMore` points the way the page was asked for: older for `newest`
/// and `before`, newer for `after`. `nextBefore` / `nextAfter` are the message ids to continue from in that direction,
/// present only when `hasMore` is and the direction applies; they may name a message the caller cannot see (blocked,
/// already held), so a page that shows nothing new still advances. Absent, paging falls back to the ids held. The
/// epoch travels on every group-scoped answer so a lost `member_left` still reaches the room (any epoch that differs
/// from the subscribed one means resubscribe).
nonisolated struct MessagePage: Hashable, Codable, Sendable {
    let items: [ChatMessage]
    let hasMore: Bool
    let channelEpoch: Int
    let nextBefore: String?
    let nextAfter: String?

    init(items: [ChatMessage], hasMore: Bool, channelEpoch: Int, nextBefore: String? = nil, nextAfter: String? = nil) {
        self.items = items
        self.hasMore = hasMore
        self.channelEpoch = channelEpoch
        self.nextBefore = nextBefore
        self.nextAfter = nextAfter
    }
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
