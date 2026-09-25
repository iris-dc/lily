import Foundation

/// The backend's `Invite`. `inviteId` is the public handle (admin list, revocation); `code` and `url` are the secret
/// and arrive only in the creation answer and the admin list, so they are optional here.
nonisolated struct Invite: Identifiable, Hashable, Codable, Sendable {
    let inviteId: String
    let code: String?
    let url: URL?
    let groupId: String
    let createdBy: String
    let createdAt: Date
    let expiresAt: Date
    /// `0` is unlimited.
    let maxUses: Int
    let uses: Int
    let revokedAt: Date?

    var id: String { inviteId }
    var isUnlimited: Bool { maxUses == 0 }
    var isRevoked: Bool { revokedAt != nil }

    /// The code as it is shown and shared, grouped in fours.
    var formattedCode: String? {
        code.map(InviteCode.grouped)
    }

    func revoked(at date: Date) -> Invite {
        Invite(inviteId: inviteId,
               code: code,
               url: url,
               groupId: groupId,
               createdBy: createdBy,
               createdAt: createdAt,
               expiresAt: expiresAt,
               maxUses: maxUses,
               uses: uses,
               revokedAt: date)
    }
}
