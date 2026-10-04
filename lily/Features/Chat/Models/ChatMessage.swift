import Foundation

/// Decodes the backend's `Message` directly: same keys, same optionality, except that missing `attachments` read as
/// none (the field arrived after the first rooms shipped). Ids are server ULIDs, so their string order is their time
/// order; every store sorts by `id`.
nonisolated struct ChatMessage: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let groupId: String
    let senderUserId: String
    /// The sender's name when the message was sent; the timeline prefers the current one from the roster.
    let senderName: String
    let kind: MessageKind
    /// Absent on system rows, on deleted messages and on a message that is its pictures alone.
    let text: String?
    /// The game an `event_created` row points at.
    let eventId: String?
    /// The tournament a tournament note points at, and the match a result or a dispute names.
    let tournamentId: String?
    let matchId: String?
    /// The id the sender chose, echoed so the optimistic bubble can be replaced; absent on system rows.
    let clientMessageId: String?
    let sentAt: Date
    let isDeleted: Bool
    /// The message this one answers, as snapshotted when it was stored; absent on plain messages and on tombstones.
    let replyTo: ReplyQuote?
    /// The pictures (later videos and files) sent with the message, with presigned links; empty on a tombstone.
    let attachments: [Attachment]

    private enum CodingKeys: String, CodingKey {
        case id, groupId, senderUserId, senderName, kind, text, eventId, tournamentId, matchId, clientMessageId, sentAt
        case isDeleted, replyTo, attachments
    }

    init(id: String,
         groupId: String,
         senderUserId: String,
         senderName: String,
         kind: MessageKind = .text,
         text: String? = nil,
         eventId: String? = nil,
         tournamentId: String? = nil,
         matchId: String? = nil,
         clientMessageId: String? = nil,
         sentAt: Date,
         isDeleted: Bool = false,
         replyTo: ReplyQuote? = nil,
         attachments: [Attachment] = []) {
        self.id = id
        self.groupId = groupId
        self.senderUserId = senderUserId
        self.senderName = senderName
        self.kind = kind
        self.text = text
        self.eventId = eventId
        self.tournamentId = tournamentId
        self.matchId = matchId
        self.clientMessageId = clientMessageId
        self.sentAt = sentAt
        self.isDeleted = isDeleted
        self.replyTo = replyTo
        self.attachments = attachments
    }

    /// Key for key like the synthesized decoder, except that missing `attachments` are none: every fixture and
    /// contract sample from before attachments must keep decoding.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try container.decode(String.self, forKey: .id),
                  groupId: try container.decode(String.self, forKey: .groupId),
                  senderUserId: try container.decode(String.self, forKey: .senderUserId),
                  senderName: try container.decode(String.self, forKey: .senderName),
                  kind: try container.decode(MessageKind.self, forKey: .kind),
                  text: try container.decodeIfPresent(String.self, forKey: .text),
                  eventId: try container.decodeIfPresent(String.self, forKey: .eventId),
                  tournamentId: try container.decodeIfPresent(String.self, forKey: .tournamentId),
                  matchId: try container.decodeIfPresent(String.self, forKey: .matchId),
                  clientMessageId: try container.decodeIfPresent(String.self, forKey: .clientMessageId),
                  sentAt: try container.decode(Date.self, forKey: .sentAt),
                  isDeleted: try container.decode(Bool.self, forKey: .isDeleted),
                  replyTo: try container.decodeIfPresent(ReplyQuote.self, forKey: .replyTo),
                  attachments: try container.decodeIfPresent([Attachment].self, forKey: .attachments) ?? [])
    }

    var isSystem: Bool { kind != .text }
    var hasAttachments: Bool { !attachments.isEmpty }

    func isSent(by userID: String?) -> Bool {
        userID != nil && senderUserId == userID
    }

    /// The same row after a delete: the text, the quote and the pictures are gone, the bubble stays as a tombstone.
    func markingDeleted() -> ChatMessage {
        ChatMessage(id: id,
                    groupId: groupId,
                    senderUserId: senderUserId,
                    senderName: senderName,
                    kind: kind,
                    eventId: eventId,
                    tournamentId: tournamentId,
                    matchId: matchId,
                    clientMessageId: clientMessageId,
                    sentAt: sentAt,
                    isDeleted: true)
    }
}
