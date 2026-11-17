import Foundation

/// The backend's answer to `POST /api/groups/{id}/invites`, `/api/tournaments/{id}/invites` or
/// `/api/events/{id}/invites`: the invite as it landed in the invitee's inbox (`id` is that inbox item's id), naming
/// the group, the tournament or the event it is into. Inviting someone who already holds a pending invite answers the
/// same one.
nonisolated struct SentInvite: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let groupId: String?
    let tournamentId: String?
    let eventId: String?
    let inviteeUserId: String
    let inviteeName: String
    let status: InviteStatus
    let createdAt: Date
    let expiresAt: Date

    init(id: String,
         groupId: String? = nil,
         tournamentId: String? = nil,
         eventId: String? = nil,
         inviteeUserId: String,
         inviteeName: String,
         status: InviteStatus,
         createdAt: Date,
         expiresAt: Date) {
        self.id = id
        self.groupId = groupId
        self.tournamentId = tournamentId
        self.eventId = eventId
        self.inviteeUserId = inviteeUserId
        self.inviteeName = inviteeName
        self.status = status
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}

/// Body of `POST /api/groups/{id}/invites`, `/api/tournaments/{id}/invites` and `/api/events/{id}/invites`.
nonisolated struct SendInvitePayload: Encodable, Equatable, Sendable {
    let userId: String
}
