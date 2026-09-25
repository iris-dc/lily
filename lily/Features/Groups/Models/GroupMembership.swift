import Foundation

/// The caller's own row in a group, as the backend decorates every `Group` it answers to a member.
nonisolated struct GroupMembership: Hashable, Codable, Sendable {
    let role: MemberRole
    let joinedAt: Date
    /// The newest message the caller has seen; absent before the first read.
    let lastReadMessageId: String?
    let hasUnread: Bool

    init(role: MemberRole, joinedAt: Date, lastReadMessageId: String? = nil, hasUnread: Bool = false) {
        self.role = role
        self.joinedAt = joinedAt
        self.lastReadMessageId = lastReadMessageId
        self.hasUnread = hasUnread
    }
}
