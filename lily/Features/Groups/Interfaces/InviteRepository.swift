import Foundation

/// Direct invites into a group, sent by a member with invite rights to someone they share a group or a game with. The
/// invitee answers from their inbox (`InboxRepository`). Failures arrive as `AppError`, ready for the popup.
protocol InviteRepository {
    /// The people the caller may invite into the group, sorted by name; members and banned users of the group are
    /// never among them, and `isInvited` marks those with a pending invite already.
    func candidates(groupID: String) async throws -> [InviteCandidate]
    /// Sends the invite; a repeat for someone with a pending invite answers that invite instead of a second one.
    func invite(groupID: String, userID: String) async throws -> SentInvite
}
