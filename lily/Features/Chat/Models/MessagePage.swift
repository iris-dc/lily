import Foundation

/// One page of a room's history, ascending by id. `hasMore` points the way the page was asked for: older for `newest`
/// and `before`, newer for `after`. `nextBefore` / `nextAfter` are the message ids to continue from in that direction,
/// present only when `hasMore` is and the direction applies; they may name a message the caller cannot see (blocked,
/// already held), so a page that shows nothing new still advances. Absent, paging falls back to the ids held. The
/// epoch travels on every group-scoped answer so a lost `member_left` still reaches the room (any epoch that differs
/// from the subscribed one means resubscribe). Every page also carries the room's pins and its poll revision, which a
/// vote moves, so a catch-up learns that polls it holds have new counts; a backend from before them sends neither,
/// read as no pins and revision 0.
nonisolated struct MessagePage: Hashable, Codable, Sendable {
    let items: [ChatMessage]
    let hasMore: Bool
    let channelEpoch: Int
    let nextBefore: String?
    let nextAfter: String?
    let pollRevision: Int
    let pins: [PinnedMessage]

    private enum CodingKeys: String, CodingKey {
        case items, hasMore, channelEpoch, nextBefore, nextAfter, pollRevision, pins
    }

    init(items: [ChatMessage],
         hasMore: Bool,
         channelEpoch: Int,
         nextBefore: String? = nil,
         nextAfter: String? = nil,
         pollRevision: Int = 0,
         pins: [PinnedMessage] = []) {
        self.items = items
        self.hasMore = hasMore
        self.channelEpoch = channelEpoch
        self.nextBefore = nextBefore
        self.nextAfter = nextAfter
        self.pollRevision = pollRevision
        self.pins = pins
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(items: try container.decode([ChatMessage].self, forKey: .items),
                  hasMore: try container.decode(Bool.self, forKey: .hasMore),
                  channelEpoch: try container.decode(Int.self, forKey: .channelEpoch),
                  nextBefore: try container.decodeIfPresent(String.self, forKey: .nextBefore),
                  nextAfter: try container.decodeIfPresent(String.self, forKey: .nextAfter),
                  pollRevision: try container.decodeIfPresent(Int.self, forKey: .pollRevision) ?? 0,
                  pins: try container.decodeIfPresent([PinnedMessage].self, forKey: .pins) ?? [])
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
/// accepts a blank text only with attachments) or a poll, which carries nothing else.
nonisolated struct SendMessagePayload: Encodable, Equatable, Sendable {
    let clientMessageId: String
    let text: String?
    let replyToMessageId: String?
    let attachments: [AttachmentRef]?
    let poll: PollPayload?

    init(clientMessageId: String,
         text: String?,
         replyToMessageId: String? = nil,
         attachments: [AttachmentRef]? = nil,
         poll: PollPayload? = nil) {
        self.clientMessageId = clientMessageId
        self.text = text
        self.replyToMessageId = replyToMessageId
        self.attachments = attachments
        self.poll = poll
    }
}

/// Body of `PUT /api/groups/{id}/read`.
nonisolated struct ReadMarkerPayload: Encodable, Equatable, Sendable {
    let messageId: String
}
