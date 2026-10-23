import Foundation

/// Fixture groups with in-memory memberships and rosters, for previews, UI tests and `-mock-events` runs. The caller
/// is whoever `identity` names at the moment of the call; the fixture memberships are theirs.
final class MockGroupRepository: GroupRepository {
    /// Stored state is internal, not private, so the `+Direct`, `+Discover` and `+Tournaments` siblings can reach it.
    var groups: [SportGroup]
    /// The other members of each group, banned rows included; the caller's own row comes from the group's membership.
    var rosters: [String: [GroupMember]]
    /// Conversations the caller cleared (`MockChatRepository.clearHistory`): out of Mine until a new line arrives.
    var hiddenConversationIDs: Set<String> = []
    let identity: any IdentityProvider
    let logger: any Logging
    let now: () -> Date

    init(identity: any IdentityProvider, logger: any Logging, now: @escaping () -> Date = { .now }) {
        let created = now()
        self.groups = MockGroupFixtures.make(now: created)
        self.rosters = Dictionary(uniqueKeysWithValues: groups.map { group in
            (group.id, MockGroupFixtures.roster(for: group.id, now: created))
        })
        self.identity = identity
        self.logger = logger
        self.now = now
    }

    func groups(in scope: GroupScope, cursor: String?, near position: Coordinate?) async throws -> Page<SportGroup> {
        logger.debug(.groups, "Mock groups served for \(scope == .mine ? "mine" : "discover")")
        switch scope {
        case .mine:
            let mine = groups.filter { !$0.isDeleted && $0.isMember && !hiddenConversationIDs.contains($0.id) }
            return Page(items: mine.sorted(by: SportGroup.mineOrder))
        case .discover(_, let type):
            return discover(prefix: scope.searchPrefix, type: type, near: position)
        }
    }

    func group(id: String) async throws -> SportGroup {
        try readable(id)
    }

    /// Like the backend: the draft's client id is the group id, so a repeated create answers the same group.
    func create(_ draft: GroupDraft) async throws -> SportGroup {
        if let existing = groups.first(where: { $0.id == draft.clientId }) {
            logger.info(.groups, "Mock create replayed for group \(existing.id)")
            return existing
        }
        let group = draft.makeGroup(ownerName: AppBranding.Groups.Create.mockOwnerName, now: now())
        groups.append(group)
        rosters[group.id] = []
        logger.info(.groups, "Group created \(group.id) (\(group.visibility.rawValue))")
        return group
    }

    func update(id: String, _ draft: GroupDraft) async throws -> SportGroup {
        let group = try readable(id)
        guard group.role?.isAdmin == true else { throw AppError.insufficientRole }
        try requireGroupRoute(group)
        return store(group.updating(with: draft))
    }

    func delete(id: String) async throws -> SportGroup {
        let group = try readable(id)
        guard group.role == .owner else { throw AppError.insufficientRole }
        try requireGroupRoute(group)
        return store(group.markingDeleted(at: now()))
    }

    func join(id: String) async throws -> SportGroup {
        let group = try readable(id)
        // Like the backend, a member joining again is answered before the group's rules are consulted.
        if group.isMember { return group }
        guard group.isPublic else { throw AppError.groupNotFound }
        try requireGroupRoute(group)
        return try admit(group, via: "public")
    }

    /// The way in for an accepted invite (`MockInboxRepository`): private groups too.
    func admit(id: String) throws -> SportGroup {
        guard let group = find(id) else { throw AppError.groupNotFound }
        return try admit(group, via: "invite")
    }

    func leave(id: String) async throws -> SportGroup {
        let group = try readable(id)
        guard let role = group.role else { throw AppError.notAMember }
        try requireGroupRoute(group)
        guard role != .owner else { throw AppError.ownerCannotLeave }
        logger.info(.groups, "Left group \(id)")
        return store(group.dropping())
    }

    func remove(id: String, userID: String) async throws -> SportGroup {
        if userID == identity.currentUserID { return try await leave(id: id) }
        let group = try readable(id)
        let target = try other(userID, in: group)
        guard GroupAccess(group: group, userID: identity.currentUserID).canRemove(target.role) else {
            throw AppError.insufficientRole
        }
        rosters[id]?.removeAll { $0.userId == userID }
        return store(group.dropping(group.membership))
    }

    func setRole(id: String, userID: String, _ role: MemberRole) async throws -> GroupMember {
        let group = try readable(id)
        let target = try other(userID, in: group)
        let access = GroupAccess(group: group, userID: identity.currentUserID)
        guard role == .banned ? access.canBan(target.role) : access.canChangeRoles else { throw AppError.insufficientRole }
        if role == .banned, target.role != .banned {
            store(group.dropping(group.membership))
        }
        return replace(target.withRole(role), in: id)
    }

    /// Members see their own row too; a public group's roster answers any signed-in caller (a guest gets the 401), a
    /// private group's is not there for outsiders (`readable`).
    func members(id: String) async throws -> [GroupMember] {
        guard let callerID = identity.currentUserID else { throw AppError.sessionExpired }
        let group = try readable(id)
        let others = others(in: id).filter { $0.role != .banned }
        guard let role = group.role, let membership = group.membership else { return others.sorted(by: Self.rosterOrder) }
        let me = GroupMember(userId: callerID,
                             displayName: AppBranding.Groups.Create.mockOwnerName,
                             role: role,
                             joinedAt: membership.joinedAt)
        return (others + [me]).sorted(by: Self.rosterOrder)
    }

    func bans(id: String) async throws -> [GroupMember] {
        let group = try readable(id)
        guard group.role?.isAdmin == true else { throw AppError.insufficientRole }
        try requireGroupRoute(group)
        return others(in: id).filter { $0.role == .banned }
    }

    func unban(id: String, userID: String) async throws {
        let group = try readable(id)
        guard group.role?.isAdmin == true else { throw AppError.insufficientRole }
        try requireGroupRoute(group)
        rosters[id]?.removeAll { $0.userId == userID && $0.role == .banned }
    }

    /// The caller's read marker, monotonic like the backend's, and the membership's `hasUnread` recomputed from it,
    /// so a Mine reload shows a room read here as read. Answers where the marker stands.
    func markRead(id: String, messageID: String) throws -> String {
        let group = try readable(id)
        guard let membership = group.membership else { throw AppError.notAMember }
        let marker = max(membership.lastReadMessageId ?? "", messageID)
        let read = GroupMembership(role: membership.role,
                                   joinedAt: membership.joinedAt,
                                   lastReadMessageId: marker,
                                   hasUnread: (group.lastMessageId ?? "") > marker)
        store(group.updatingMembership(read, memberCount: group.memberCount))
        return marker
    }

    /// A new line in the room: the group's last message moves to it, as the backend's bookkeeping does after a send.
    func noteMessage(_ message: ChatMessage, in groupID: String) {
        guard let moved = find(groupID)?.noting(message) else { return }
        _ = store(moved)
    }

    private func admit(_ group: SportGroup, via: String) throws -> SportGroup {
        if group.isMember { return group }
        guard !group.isFull else { throw AppError.groupFull }
        logger.info(.groups, "Joined group \(group.id) (\(via))")
        return store(group.updatingMembership(membershipOnJoin(of: group), memberCount: group.memberCount + 1))
    }

    /// The row of someone joining now: a member, read up to the room's latest message.
    func membershipOnJoin(of group: SportGroup) -> GroupMembership {
        GroupMembership(role: .member, joinedAt: now(), lastReadMessageId: group.lastMessageId)
    }

    /// The group as a reader may see it: a private group is not there for anyone who is not in it.
    private func readable(_ id: String) throws -> SportGroup {
        guard let group = find(id), group.isPublic || group.isMember else { throw AppError.groupNotFound }
        return group
    }

    /// The backend's `requireGroupKind`: a conversation and a tournament's room are entered and left through the
    /// person or the tournament, so the group routes answer FORBIDDEN; an unknown kind passes, as there.
    private func requireGroupRoute(_ group: SportGroup) throws {
        guard !group.isDirect, !group.isTournamentRoom else { throw AppError.insufficientRole }
    }

    func find(_ id: String) -> SportGroup? {
        groups.first { $0.id == id && !$0.isDeleted }
    }

    /// The other members of a group with its banned rows, live: the invite mock sifts them the way the backend does.
    func roster(of groupID: String) -> [GroupMember] {
        others(in: groupID)
    }

    private func others(in groupID: String) -> [GroupMember] {
        rosters[groupID] ?? []
    }

    private func other(_ userID: String, in group: SportGroup) throws -> GroupMember {
        guard let member = others(in: group.id).first(where: { $0.userId == userID }) else { throw AppError.notAMember }
        return member
    }

    /// The one replace of a stored group; the `+Tournaments` extension writes its rooms through it too.
    @discardableResult
    func store(_ group: SportGroup) -> SportGroup {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
        }
        return group
    }

    private func replace(_ member: GroupMember, in groupID: String) -> GroupMember {
        if let index = rosters[groupID]?.firstIndex(where: { $0.userId == member.userId }) {
            rosters[groupID]?[index] = member
        }
        return member
    }

    /// Owner first, then admins, then by join time, as the backend orders a roster.
    private static func rosterOrder(_ lhs: GroupMember, _ rhs: GroupMember) -> Bool {
        let rank: (MemberRole) -> Int = { $0 == .owner ? 0 : $0 == .admin ? 1 : 2 }
        return rank(lhs.role) != rank(rhs.role) ? rank(lhs.role) < rank(rhs.role) : lhs.joinedAt < rhs.joinedAt
    }
}
