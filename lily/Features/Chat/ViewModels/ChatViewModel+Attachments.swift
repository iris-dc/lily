import Foundation

/// Attachments in the composer and on the bubbles. The drafts live in the owned `AttachmentComposerModel`; the message
/// draft takes them at the moment of the send (`outgoingDraft`), and the stored message that replaces the bubble seeds
/// the cache with the bubble's files under the ids the backend gave them, so a picture just sent never downloads.
extension ChatViewModel {
    /// Whether the backend takes attachments (`GET /api/me`); the attach button hides otherwise.
    var attachmentsEnabled: Bool { me.attachmentsEnabled }

    /// The draft as it would be sent now: the words with the pictures the composer holds.
    var outgoingDraft: MessageDraft {
        var draft = self.draft
        draft.attachments = attachments.drafts
        return draft
    }

    /// The stored message replaced the bubble of `clientMessageID` (the answer, the live echo or a catch-up, whichever
    /// came first): the bubble's files go into the cache under the stored ids before the bubble goes, since they are
    /// known only through it. `seedCache` claims each id before its first await, so a second settle copies and deletes
    /// nothing.
    func confirmPending(clientMessageID: String, with message: ChatMessage) async {
        if message.hasAttachments, let sent = pending.first(where: { $0.clientMessageID == clientMessageID }) {
            await attachments.seedCache(sent.attachments, with: message.attachments)
        }
        pending.removeAll { $0.clientMessageID == clientMessageID }
    }
}
