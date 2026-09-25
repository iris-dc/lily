import Foundation

/// Groups boundary. Every write answers the group (or member) as the server now sees it, so screens show the real
/// counts and roles. Failures arrive as `AppError`, ready for the popup.
protocol GroupRepository {
    /// `.mine` answers every group the caller is in, most recently active first, in one page; `.discover` pages
    /// through the public groups with `cursor` from the previous page's `nextCursor`.
    func groups(in scope: GroupScope, cursor: String?) async throws -> Page<SportGroup>
    /// Throws `AppError.groupNotFound` when it is gone, and for a private group the caller is not in.
    func group(id: String) async throws -> SportGroup
    /// Creates the group for the caller, who owns it and is its first member. Repeating a create with the same
    /// `GroupDraft.clientId` answers the same group instead of a second one.
    func create(_ draft: GroupDraft) async throws -> SportGroup
    func update(id: String, _ draft: GroupDraft) async throws -> SportGroup
    /// Soft delete; the answer carries `deletedAt`. Owners and operators only.
    func delete(id: String) async throws -> SportGroup
    /// Public groups only; a private one needs an invite (`InviteRepository.redeem`).
    func join(id: String) async throws -> SportGroup
    func leave(id: String) async throws -> SportGroup
    func remove(id: String, userID: String) async throws -> SportGroup
    /// `.admin` and `.member` for owners; `.banned` for admins on members and owners on members and admins.
    func setRole(id: String, userID: String, _ role: MemberRole) async throws -> GroupMember
    /// Members only, in every group: owner first, then admins, then by join time.
    func members(id: String) async throws -> [GroupMember]
    /// Admins only: the banned markers, `joinedAt` being the ban time.
    func bans(id: String) async throws -> [GroupMember]
    func unban(id: String, userID: String) async throws
}
