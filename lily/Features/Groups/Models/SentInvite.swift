import Foundation

/// The backend's answer to `POST /api/groups/{id}/invites`: the invite as it landed in the invitee's inbox (`id` is
/// that inbox item's id). Inviting someone who already holds a pending invite answers the same one.
nonisolated struct SentInvite: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let groupId: String
    let inviteeUserId: String
    let inviteeName: String
    let status: InviteStatus
    let createdAt: Date
    let expiresAt: Date
}

/// Body of `POST /api/groups/{id}/invites`.
nonisolated struct SendInvitePayload: Encodable, Equatable, Sendable {
    let userId: String
}
