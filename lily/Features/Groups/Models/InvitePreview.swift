import Foundation

/// What `POST /api/invites/preview` tells about an invite before the caller joins: enough for the card, nothing that
/// needs membership.
nonisolated struct InvitePreview: Hashable, Codable, Sendable {
    struct GroupSummary: Hashable, Codable, Sendable {
        let id: String
        let name: String
        let description: String?
        let visibility: GroupVisibility
        let type: EventType?
        let memberCount: Int
    }

    let group: GroupSummary
    let expiresAt: Date
    /// False for guests, whatever their account's state.
    let isMember: Bool
}
