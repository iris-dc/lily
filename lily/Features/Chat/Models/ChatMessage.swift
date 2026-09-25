import Foundation

/// Decodes the backend's `Message` directly: same keys, same optionality. Ids are server ULIDs, so their string order
/// is their time order; every store sorts by `id`.
nonisolated struct ChatMessage: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let groupId: String
    let senderUserId: String
    /// The sender's name when the message was sent; the timeline prefers the current one from the roster.
    let senderName: String
    let kind: MessageKind
    /// Absent on system rows and on deleted messages.
    let text: String?
    /// The game an `event_created` row points at.
    let eventId: String?
    /// The id the sender chose, echoed so the optimistic bubble can be replaced; absent on system rows.
    let clientMessageId: String?
    let sentAt: Date
    let isDeleted: Bool

    init(id: String,
         groupId: String,
         senderUserId: String,
         senderName: String,
         kind: MessageKind = .text,
         text: String? = nil,
         eventId: String? = nil,
         clientMessageId: String? = nil,
         sentAt: Date,
         isDeleted: Bool = false) {
        self.id = id
        self.groupId = groupId
        self.senderUserId = senderUserId
        self.senderName = senderName
        self.kind = kind
        self.text = text
        self.eventId = eventId
        self.clientMessageId = clientMessageId
        self.sentAt = sentAt
        self.isDeleted = isDeleted
    }

    var isSystem: Bool { kind != .text }

    func isSent(by userID: String?) -> Bool {
        userID != nil && senderUserId == userID
    }

    /// The same row after a delete: the text is gone, the bubble stays as a tombstone.
    func markingDeleted() -> ChatMessage {
        ChatMessage(id: id,
                    groupId: groupId,
                    senderUserId: senderUserId,
                    senderName: senderName,
                    kind: kind,
                    eventId: eventId,
                    clientMessageId: clientMessageId,
                    sentAt: sentAt,
                    isDeleted: true)
    }
}
