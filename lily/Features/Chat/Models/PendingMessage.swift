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
    var state: State = .sending

    var id: String { clientMessageID }
    var hasFailed: Bool { state == .failed }

    init(draft: MessageDraft, sentAt: Date) {
        clientMessageID = draft.clientMessageID
        text = draft.trimmedText
        self.sentAt = sentAt
    }

    /// The draft to send again, with the same id so the backend replays instead of duplicating.
    var draft: MessageDraft {
        var draft = MessageDraft(clientMessageID: clientMessageID)
        draft.text = text
        return draft
    }
}
