import Foundation

/// A message of the caller's that the backend has not confirmed: shown at once as a faded bubble, replaced by the
/// stored message when the answer or the live echo arrives, or marked failed with Retry. In memory only.
nonisolated struct PendingMessage: Identifiable, Hashable, Sendable {
    enum State: Hashable, Sendable {
        case sending
        case failed
    }

    let clientMessageID: String
    let text: String
    let sentAt: Date
    /// The quote the bubble shows and the retry sends; dropped once the backend said the original is gone.
    private(set) var replyTo: ReplyQuote?
    /// The pictures the bubble previews from their files on the device, and the retry names again.
    let attachments: [AttachmentDraft]
    var state: State = .sending

    var id: String { clientMessageID }
    var hasFailed: Bool { state == .failed }
    var hasAttachments: Bool { !attachments.isEmpty }

    init(draft: MessageDraft, sentAt: Date) {
        clientMessageID = draft.clientMessageID
        text = draft.trimmedText
        replyTo = draft.replyTo
        attachments = draft.attachments
        self.sentAt = sentAt
    }

    /// The draft to send again, with the same id so the backend replays instead of duplicating.
    var draft: MessageDraft {
        var draft = MessageDraft(clientMessageID: clientMessageID)
        draft.text = text
        draft.replyTo = replyTo
        draft.attachments = attachments
        return draft
    }

    /// The same message as a plain one, for a retry after `REPLY_TARGET_NOT_FOUND`.
    func droppingReply() -> PendingMessage {
        var copy = self
        copy.replyTo = nil
        return copy
    }
}
