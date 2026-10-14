import Foundation

/// The rooms of the tournament mock: a tournament's room is a group of kind `tournament` under the tournament's id,
/// owned by its organiser, which players enter and leave through the tournament's entries, never through the group
/// routes. The fixtures ship two (`MockTournamentFixtures.rooms`); a created tournament registers its own here.
extension MockGroupRepository {
    /// The room of a tournament the caller just created: they own it, nobody else is in yet.
    func registerRoom(for tournament: Tournament, memberCount: Int) {
        guard find(tournament.id) == nil else { return }
        let membership = GroupMembership(role: .owner, joinedAt: tournament.createdAt)
        let room = MockTournamentFixtures.room(for: tournament,
                                               organizerName: AppBranding.Groups.Create.mockOwnerName,
                                               memberCount: memberCount,
                                               membership: membership)
        groups.append(room)
        rosters[room.id] = []
        logger.info(.groups, "Mock room registered for tournament \(tournament.id)")
    }

    /// The room follows the tournament: its name after an edit, its member count after every entry change; the
    /// caller's membership and the chat's bookkeeping stay as they were.
    func syncRoom(for tournament: Tournament, memberCount: Int) {
        guard let index = groups.firstIndex(where: { $0.id == tournament.id }) else { return }
        let stored = groups[index]
        groups[index] = MockTournamentFixtures.room(for: tournament,
                                                    organizerName: stored.ownerName,
                                                    memberCount: memberCount,
                                                    membership: stored.membership,
                                                    lastMessageId: stored.lastMessageId,
                                                    lastMessageAt: stored.lastMessageAt)
    }

    /// The caller entered the tournament: a member of its room, unless they own it already.
    func admitToRoom(id: String) {
        guard let group = find(id), !group.isMember else { return }
        store(group.updatingMembership(membershipOnJoin(of: group), memberCount: group.memberCount + 1))
        logger.info(.groups, "Joined room \(id) (tournament entry)")
    }

    /// A player left the tournament: the caller (`nil`) loses their membership unless they organise it; another
    /// player leaves the roster. The room's epoch follows the tournament's through the `syncRoom` every departure
    /// ends with, so nothing rotates here.
    func leaveRoom(id: String, userID: String?) {
        guard let group = find(id) else { return }
        if let userID {
            rosters[id]?.removeAll { $0.userId == userID }
            store(group.updatingMembership(group.membership, memberCount: group.memberCount - 1))
        } else if group.role != .owner, group.isMember {
            store(group.updatingMembership(nil, memberCount: group.memberCount - 1))
            logger.info(.groups, "Left room \(id) (tournament entry)")
        }
    }
}
