import Foundation

/// Pictures in the composer. The drafts live in the owned `AttachmentComposerModel`; the message draft takes them
/// at the moment of the send (`outgoingDraft`), and the stored message's files seed the cache under the ids the
/// backend gave them, so a picture just sent never downloads.
extension ChatViewModel {
    /// Whether the backend takes attachments (`GET /api/me`); the attach button hides otherwise.
    var attachmentsEnabled: Bool { me.attachmentsEnabled }

    /// The draft as it would be sent now: the words with the pictures the composer holds.
    var outgoingDraft: MessageDraft {
        var draft = self.draft
        draft.attachments = attachments.drafts
        return draft
    }

    /// The stored message replaced the bubble of `clientMessageID` (the answer or the live echo, whichever came
    /// first): its local files go into the cache under the stored ids.
    func seedAttachmentCache(for clientMessageID: String, with message: ChatMessage) {
        guard message.hasAttachments,
              let sent = pending.first(where: { $0.clientMessageID == clientMessageID }) else { return }
        attachments.seedCache(sent.attachments, with: message.attachments)
    }
}
