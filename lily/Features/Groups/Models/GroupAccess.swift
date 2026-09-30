import Foundation

/// What a group offers the caller, decided in one place from the group and the caller's id so the screens and their
/// tests agree. The analogue of `Participation`. The server stays the authority: a stale role only changes which
/// buttons show, every call is re-checked there. A direct conversation is its own case: chat and the two-person
/// roster, nothing a group offers beyond that (the backend refuses those too).
nonisolated enum GroupAccess: Equatable, Sendable {
    /// Guests see the group; joining needs an account.
    case guest
    case canJoin
    /// A private group the caller is not in; entered only by accepting an invite from the inbox.
    case inviteOnly
    case member(MemberRole)
    /// No seats left and the caller is not in.
    case full
    /// The caller's side of a direct conversation.
    case conversation

    init(group: SportGroup, userID: String?) {
        guard userID != nil else {
            self = .guest
            return
        }
        if group.isDirect, group.isMember {
            self = .conversation
        } else if let role = group.role {
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

    var isMember: Bool { role != nil || self == .conversation }
    var canChat: Bool { isMember }
    /// Owners cannot leave; nobody leaves a conversation.
    var canLeave: Bool { role.map { $0 != .owner } ?? false }
    var canEdit: Bool { role?.isAdmin ?? false }
    var canDelete: Bool { role == .owner }
    var canChangeRoles: Bool { role == .owner }

    /// Members see the roster of any group; a public group's is open to every signed-in caller, a private group's
    /// stays members-only. Guests see none: the backend answers the roster route with a token only.
    func canSeeMembers(in group: SportGroup) -> Bool {
        isMember || (self != .guest && group.isPublic)
    }

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
