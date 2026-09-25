import Foundation

/// Invites boundary. The code is a capability: `preview` and `redeem` send it in the request body, never in a path.
protocol InviteRepository {
    /// Admins, or members when the group allows it. The answer carries the code and the link to share.
    func create(groupID: String, options: InviteOptions) async throws -> Invite
    /// Admins only: the active invites, codes included.
    func list(groupID: String) async throws -> [Invite]
    /// By the invite's public handle; admins of the group or the invite's creator. Twice answers the same invite.
    func revoke(groupID: String, inviteID: String) async throws -> Invite
    /// Anonymous: what the invite leads to, before joining.
    func preview(code: InviteCode) async throws -> InvitePreview
    /// Joins the group behind the code; an existing member is welcomed with the same group.
    func redeem(code: InviteCode) async throws -> SportGroup
}
