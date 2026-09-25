import Foundation

/// The backend's `Member`: one row of a group's roster, or of its banned list (`role: banned`, `joinedAt` = ban time).
nonisolated struct GroupMember: Identifiable, Hashable, Codable, Sendable {
    let userId: String
    let displayName: String
    let role: MemberRole
    let joinedAt: Date

    var id: String { userId }

    /// The same row in another role, after a promotion, demotion or ban.
    func withRole(_ role: MemberRole) -> GroupMember {
        GroupMember(userId: userId, displayName: displayName, role: role, joinedAt: joinedAt)
    }
}

/// Answer of `DELETE /api/groups/{id}/bans/{userId}`.
nonisolated struct UnbanReceipt: Decodable, Equatable, Sendable {
    let unbanned: Bool
}
