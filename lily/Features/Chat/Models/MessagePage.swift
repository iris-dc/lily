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

/// Answer of `DELETE /api/groups/{id}/messages`: the caller's new history floor (everything stored before it is gone
/// from their pages alone), `hidden` only for a conversation, which then leaves Mine until someone writes again.
nonisolated struct ClearedHistory: Hashable, Codable, Sendable {
    let historyFloor: String
    let hidden: Bool
    let channelEpoch: Int
}

/// Body of `POST /api/groups/{id}/messages`; every optional is omitted, never `null`: `replyToMessageId` on a plain
/// message, `attachments` on a message without any, and `text` on a message that is its pictures alone (the backend
/// accepts a blank text only with attachments).
nonisolated struct SendMessagePayload: Encodable, Equatable, Sendable {
    let clientMessageId: String
    let text: String?
    let replyToMessageId: String?
    let attachments: [AttachmentRef]?

    init(clientMessageId: String, text: String?, replyToMessageId: String? = nil, attachments: [AttachmentRef]? = nil) {
        self.clientMessageId = clientMessageId
        self.text = text
        self.replyToMessageId = replyToMessageId
        self.attachments = attachments
    }
}

/// Body of `PUT /api/groups/{id}/read`.
nonisolated struct ReadMarkerPayload: Encodable, Equatable, Sendable {
    let messageId: String
}
