import Foundation

/// The inbox routes (`/api/me/inbox`): the caller's invites and game reminders. Every page is ascending by id;
/// failures arrive as `AppError`, ready for the popup.
protocol InboxRepository {
    /// The newest `limit` items without `before`, the `limit` items before `before` with it; `hasMore` means older
    /// ones exist.
    func page(before itemID: String?, limit: Int) async throws -> InboxPage
    /// Monotonic: an older id leaves the marker where it was, and the answer says where it is.
    func markRead(itemID: String) async throws -> String
    /// Joins the invite's group; a repeat on an accepted invite answers the same shape.
    func accept(itemID: String) async throws -> InviteAcceptance
    /// A repeat on a declined invite answers the same item.
    func decline(itemID: String) async throws -> InboxItem
}
