import Foundation

/// A pinned message as every page lists it (oldest first): the quote the backend snapshotted when it was pinned, and
/// when. The bar at the top of the chat shows it without the message being held; a tap reaches the message itself.
nonisolated struct PinnedMessage: Identifiable, Hashable, Codable, Sendable {
    let messageId: String
    let senderUserId: String
    let senderName: String
    let excerpt: String?
    let kind: MessageKind
    let attachmentKind: AttachmentKind?
    let pinnedAt: Date

    var id: String { messageId }

    var quote: ReplyQuote {
        ReplyQuote(messageId: messageId,
                   senderUserId: senderUserId,
                   senderName: senderName,
                   excerpt: excerpt,
                   kind: kind,
                   attachmentKind: attachmentKind)
    }
}

nonisolated extension PinnedMessage {
    /// A pin made from a message's quote, as the backend makes one: the mocks' and fixtures' way to pin.
    init(quote: ReplyQuote, pinnedAt: Date) {
        self.init(messageId: quote.messageId,
                  senderUserId: quote.senderUserId,
                  senderName: quote.senderName,
                  excerpt: quote.excerpt,
                  kind: quote.kind,
                  attachmentKind: quote.attachmentKind,
                  pinnedAt: pinnedAt)
    }
}

/// Answer of `PUT` and `DELETE /api/groups/{id}/pins/{messageId}`: the chat's pins after the change.
nonisolated struct PinList: Hashable, Codable, Sendable {
    let pins: [PinnedMessage]
    let channelEpoch: Int
}
