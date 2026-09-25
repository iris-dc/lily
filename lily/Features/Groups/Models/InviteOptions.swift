import Foundation

/// Body of `POST /api/groups/{id}/invites`.
nonisolated struct InviteOptions: Encodable, Hashable, Sendable {
    /// `0` is unlimited.
    let maxUses: Int
    let expiresInDays: Int

    init(maxUses: Int = AppConfig.Groups.inviteDefaultUses, expiresInDays: Int = AppConfig.Groups.inviteDefaultDays) {
        self.maxUses = maxUses
        self.expiresInDays = expiresInDays
    }
}
