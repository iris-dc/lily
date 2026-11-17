import Foundation

/// The rooms of the fixture events as the group mock lists them, and the rosters behind them; a file of its own so the
/// fixture enum stays under the type-body limit (the tournament fixtures' pattern).
nonisolated extension MockEventFixtures {
    /// Every fixture event's id starts with it; the group fixtures route a roster by it.
    static let eventIDPrefix = "mock-event-"
    /// Every n-th fixture starts out joined so the Home tab has content; four leaves the full basketball game unjoined.
    static let joinedStride = 4
    /// The one event room with chat lines (`MockChatFixtures`); the caller joined it, so Chats lists it with history.
    static let sunsetEventID = "mock-event-0"
    /// How long before the launch the sunset room's last line was written: between the table-tennis room (3 h) and
    /// Tempelhof Runners (26 h), so the Chats order the pinned walks read keeps its head.
    static let sunsetRoomLastMessageAge: TimeInterval = 5 * .hour
    /// Silent event rooms sit deep in Chats (below every row with a message), an hour apart so the order is
    /// deterministic.
    private static let roomAge: TimeInterval = 9 * .day
    private static let roomAgeSpacing: TimeInterval = .hour
    private static let roomJoinAge: TimeInterval = .day

    static func isInitiallyJoined(index: Int) -> Bool {
        index.isMultiple(of: joinedStride)
    }

    /// The rooms of every fixture event: the caller is a member of the ones the stride pre-joins, so Chats lists
    /// those; the rest stand ready for a join. All start read, so the fixtures' unread rooms stay Kickers and Marta.
    static func rooms(now: Date) -> [SportGroup] {
        feed(now: now).enumerated().map { index, event in
            let lastMessageID = MockChatFixtures.lastMessageID(for: event.id)
            return room(for: event,
                        membership: isInitiallyJoined(index: index) ? membership(lastRead: lastMessageID, now: now) : nil,
                        lastMessageId: lastMessageID,
                        lastMessageAt: event.id == sunsetEventID ? now.addingTimeInterval(-sunsetRoomLastMessageAge) : nil,
                        createdAt: now.addingTimeInterval(-roomAge - Double(index) * roomAgeSpacing))
        }
    }

    /// An event's room as the backend shapes one: under the event's id, named after it, the event's effective
    /// visibility (a private group's event gets a private room) and type, the host as owner, `capacity + 1` seats or
    /// the groups' ceiling, the event's epoch mirror, no group powers.
    static func room(for event: SportEvent,
                     membership: GroupMembership?,
                     lastMessageId: String? = nil,
                     lastMessageAt: Date? = nil,
                     createdAt: Date) -> SportGroup {
        SportGroup(id: event.id,
                   name: event.title,
                   visibility: (event.group?.isPrivate ?? false) ? .private : .public,
                   type: event.type,
                   ownerName: event.hostName,
                   memberCount: event.participantCount,
                   maxMembers: event.capacity.map { $0 + 1 } ?? AppConfig.Groups.maxMembers,
                   channelEpoch: event.channelEpoch,
                   membersCanCreateEvents: false,
                   membersCanInvite: false,
                   lastMessageId: lastMessageId,
                   lastMessageAt: lastMessageAt,
                   createdAt: createdAt,
                   membership: membership,
                   kind: .event)
    }

    /// The other members of an event's room (never the caller): the host as owner, then the deterministic roster the
    /// participant lists use, so a member's profile resolves against the group mock. Oldest first.
    static func roster(for eventID: String, now: Date) -> [GroupMember] {
        let events = feed(now: now)
        guard let index = events.firstIndex(where: { $0.id == eventID }) else { return [] }
        let event = events[index]
        let hostJoinedAt = event.startsAt.addingTimeInterval(-hostJoinLead)
        let host = GroupMember(userId: MockGroupFixtures.memberID(for: event.hostName),
                               displayName: event.hostName,
                               role: .owner,
                               joinedAt: hostJoinedAt)
        let othersCount = max(event.participantCount - 1 - (isInitiallyJoined(index: index) ? 1 : 0), 0)
        let others = participantNames(for: event, count: othersCount).enumerated().map { offset, name in
            GroupMember(userId: MockGroupFixtures.memberID(for: name),
                        displayName: name,
                        role: .member,
                        joinedAt: hostJoinedAt.addingTimeInterval(Double(offset + 1) * joinSpacing))
        }
        return [host] + others
    }

    private static func membership(lastRead: String?, now: Date) -> GroupMembership {
        GroupMembership(role: .member, joinedAt: now.addingTimeInterval(-roomJoinAge), lastReadMessageId: lastRead)
    }
}
