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
}
