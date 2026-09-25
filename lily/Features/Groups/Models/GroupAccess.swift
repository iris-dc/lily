import Foundation

/// What a group offers the caller, decided in one place from the group and the caller's id so the screens and their
/// tests agree. The analogue of `Participation`. The server stays the authority: a stale role only changes which
/// buttons show, every call is re-checked there.
nonisolated enum GroupAccess: Equatable, Sendable {
    /// Guests see the group; joining needs an account.
    case guest
    case canJoin
    /// A private group the caller is not in; reached only through an invite preview.
    case inviteOnly
    case member(MemberRole)
    /// No seats left and the caller is not in.
    case full

    init(group: SportGroup, userID: String?) {
        guard userID != nil else {
            self = .guest
            return
        }
        if let role = group.role {
            self = .member(role)
        } else if group.isFull {
            self = .full
        } else if group.isPublic {
            self = .canJoin
        } else {
            self = .inviteOnly
        }
    }

    private var role: MemberRole? {
        if case .member(let role) = self { return role }
        return nil
    }

    var canChat: Bool { role != nil }
    /// The roster is members-only in every group.
    var canSeeMembers: Bool { role != nil }
    var canLeave: Bool { role != nil && role != .owner }
    var canEdit: Bool { role?.isAdmin ?? false }
    var canDelete: Bool { role == .owner }
    var canChangeRoles: Bool { role == .owner }

    /// Owners and admins always; members when the group allows it.
    func canCreateEvents(in group: SportGroup) -> Bool {
        allows(group.membersCanCreateEvents)
    }

    func canInvite(in group: SportGroup) -> Bool {
        allows(group.membersCanInvite)
    }

    /// Admins act on members; owners on members and admins; nobody on the owner.
    func canRemove(_ other: MemberRole) -> Bool {
        switch role {
        case .owner: other == .member || other == .admin
        case .admin: other == .member
        default: false
        }
    }

    func canBan(_ other: MemberRole) -> Bool {
        canRemove(other)
    }

    private func allows(_ membersMay: Bool) -> Bool {
        guard let role else { return false }
        return role.isAdmin || membersMay
    }
}
