import Foundation

/// The rooms of the event mock: an event's room is a group of kind `event` under the event's id, owned by its host,
/// which players enter and leave through the event's participation, never through the group routes. The fixtures ship
/// one per fixture event (`MockEventFixtures.rooms`); a created event registers its own here, and every participation
/// write mirrors the event's count and epoch into the room, as the backend's transaction does.
extension MockGroupRepository {
    /// The room of an event the group fixtures do not ship: the caller owns the one they just created; in an event
    /// appended to the fixtures they are a member at most (`role` nil when they never joined).
    func registerEventRoom(for event: SportEvent, role: MemberRole? = .owner) {
        guard find(event.id) == nil else { return }
        let membership = role.map { GroupMembership(role: $0, joinedAt: now()) }
        groups.append(MockEventFixtures.room(for: event, membership: membership, createdAt: now()))
        rosters[event.id] = []
        logger.info(.groups, "Mock room registered for event \(event.id)")
    }

    /// The room follows the event: its name and size after an edit, its count and epoch after every join and leave;
    /// the caller's membership and the chat's bookkeeping stay as they were.
    func syncEventRoom(for event: SportEvent) {
        guard let index = groups.firstIndex(where: { $0.id == event.id }) else { return }
        let stored = groups[index]
        groups[index] = MockEventFixtures.room(for: event,
                                               membership: stored.membership,
                                               lastMessageId: stored.lastMessageId,
                                               lastMessageAt: stored.lastMessageAt,
                                               createdAt: stored.createdAt)
    }

    /// The caller joined the event: a member of its room, with the count and epoch the event now carries.
    func admitToEventRoom(for event: SportEvent) {
        if let room = find(event.id), !room.isMember {
            store(room.updatingMembership(membershipOnJoin(of: room), memberCount: room.memberCount))
            logger.info(.groups, "Joined room \(event.id) (event join)")
        }
        syncEventRoom(for: event)
    }

    /// The caller left the event: their membership goes, and the room takes the event's bumped epoch, so the realtime
    /// channel rotates like the backend's.
    func leaveEventRoom(for event: SportEvent) {
        if let room = find(event.id), room.isMember {
            store(room.updatingMembership(nil, memberCount: room.memberCount))
            logger.info(.groups, "Left room \(event.id) (event leave)")
        }
        syncEventRoom(for: event)
    }
}
