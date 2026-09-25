import Foundation

/// A member's role, as data on the backend's member row. `banned` marks a former member who cannot rejoin.
nonisolated enum MemberRole: String, CaseIterable, Codable, Sendable {
    case owner, admin, member, banned

    /// Owners and admins run the group: settings, invites, removals and bans.
    var isAdmin: Bool {
        self == .owner || self == .admin
    }

    var displayName: String {
        switch self {
        case .owner: AppBranding.Groups.ownerRole
        case .admin: AppBranding.Groups.adminRole
        case .member: AppBranding.Groups.memberRole
        case .banned: AppBranding.Groups.bannedSection
        }
    }
}

/// Body of `PUT /api/groups/{id}/members/{userId}`.
nonisolated struct RoleChangePayload: Encodable, Equatable, Sendable {
    let role: MemberRole
}
