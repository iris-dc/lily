import Foundation

/// The chat routes. Every page is ascending by id and carries the room's epoch; failures arrive as `AppError`.
protocol ChatRepository {
    /// The newest `AppConfig.Chat.historyPageSize` messages the caller may see; `hasMore` means older ones exist.
    func newest(groupID: String) async throws -> MessagePage
    /// The page before `before`; `hasMore` means older ones exist.
    func older(groupID: String, before messageID: String) async throws -> MessagePage
    /// The catch-up: everything after `after` (with the backend's lookback, so ids already held may repeat), up to
    /// `AppConfig.Chat.catchUpPageSize`; `hasMore` means newer ones exist.
    func newer(groupID: String, after messageID: String) async throws -> MessagePage
    /// Repeating a send with the same `clientMessageID` answers the stored message instead of a second one.
    func send(groupID: String, _ draft: MessageDraft) async throws -> SentMessage
    /// Sender, admin or operator; answers the tombstone. Twice is fine.
    func delete(groupID: String, messageID: String) async throws -> ChatMessage
    /// Monotonic: an older id leaves the marker where it was, and the answer says where it is.
    func markRead(groupID: String, messageID: String) async throws -> ReadMarker
    /// Moves the caller's history floor to now (and hides a conversation from their Mine): the caller alone stops
    /// seeing what came before. Twice is fine.
    func clearHistory(groupID: String) async throws -> ClearedHistory
    /// A presigned upload for one attachment of a message about to be sent in the group; the PUT itself goes through
    /// `AttachmentUploader`, and the send names the ticket's `attachmentId`.
    func requestUpload(groupID: String, _ request: UploadRequestPayload) async throws -> UploadTicket
    /// Fresh presigned links for an attachment whose links expired or were refused; the message id is in the path
    /// because the caller's history floor is checked against the message.
    func refreshAttachment(groupID: String, messageID: String, attachmentID: String) async throws -> AttachmentLink
}
