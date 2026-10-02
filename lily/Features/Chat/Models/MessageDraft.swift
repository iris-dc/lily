import Foundation

/// What the composer holds. The id is chosen once per composed message and sent with every attempt, so a retry after
/// a lost answer replays the stored message instead of posting it twice. Length is UTF-16 units, as the backend counts.
/// A draft is sendable with words, or with at least one uploaded picture; while a picture is still on its way (or
/// failed, which the sender must retry or remove) it is not.
nonisolated struct MessageDraft: Equatable, Sendable {
    /// Lower-case, as the backend stores it.
    let clientMessageID: String
    var text = ""
    /// The message this draft answers; the payload sends its id and the backend snapshots the quote.
    var replyTo: ReplyQuote?
    /// The pictures going with the words, as the composer's `AttachmentComposerModel` holds them.
    var attachments: [AttachmentDraft] = []

    init(clientMessageID: String = UUID().uuidString.lowercased()) {
        self.clientMessageID = clientMessageID
    }

    enum Issue: Hashable, Sendable {
        case empty
        case tooLong
        /// A picture is not uploaded yet: still preparing or uploading, or failed and waiting for Retry or removal.
        case attachmentsPending
    }

    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The pictures the send may name.
    var uploadedRefs: [AttachmentRef] { attachments.compactMap(\.uploadedRef) }

    var issues: [Issue] {
        var issues: [Issue] = []
        if trimmedText.isEmpty && uploadedRefs.isEmpty { issues.append(.empty) }
        if trimmedText.wireLength > AppConfig.Chat.messageMaxLength { issues.append(.tooLong) }
        if attachments.contains(where: { $0.uploadedRef == nil }) { issues.append(.attachmentsPending) }
        return issues
    }

    var isValid: Bool { issues.isEmpty }

    /// Characters the backend still accepts; negative once the draft is too long.
    var remaining: Int { AppConfig.Chat.messageMaxLength - text.wireLength }

    var payload: SendMessagePayload {
        let refs = uploadedRefs
        return SendMessagePayload(clientMessageId: clientMessageID,
                                  text: trimmedText.isEmpty ? nil : trimmedText,
                                  replyToMessageId: replyTo?.messageId,
                                  attachments: refs.isEmpty ? nil : refs)
    }
}
