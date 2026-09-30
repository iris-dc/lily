import Foundation

/// The six groups of a mock run: three the caller is in (as member, admin and owner), one to join, one that is full,
/// and one private group reachable only through the mock inbox's invite (`MockInboxFixtures`); plus one direct
/// conversation, with Marta, unread, so the Chats tab shows a person row from the start.
nonisolated enum MockGroupFixtures {
    static let kickersID = "mock-group-kickers"
    static let runnersID = "mock-group-runners"
    static let padelID = "mock-group-padel"
    static let basketballID = "mock-group-basketball"
    static let volleyID = "mock-group-volley"
    static let climbingID = "mock-group-climbing"
    /// The other side of the fixture conversation; `startDirect(with:)` for her answers the fixture instead of a new room.
    static let conversationCounterpart = Counterpart(userId: memberID(for: "Marta"), displayName: "Marta")
    static let martaConversationID = directConversationID(for: conversationCounterpart.userId)

    private struct Template {
        let id: String
        let name: String
        let description: String
        let visibility: GroupVisibility
        let type: EventType
        let ownerName: String
        let memberCount: Int
        var maxMembers = AppConfig.Groups.maxMembers
        /// The caller's role, `nil` when they are not in.
        var role: MemberRole?
        var hasUnread = false
        /// Hours since the last message; `nil` for a silent group.
        var lastMessageHoursAgo: Double?
        let createdDaysAgo: Double
        /// The other members shown on the roster (never the caller): name and role.
        let roster: [(name: String, role: MemberRole)]
    }

    private static let templates: [Template] = [
        Template(
            id: kickersID,
            name: "Kreuzberg Kickers",
            description: "Casual 5-a-side around Görlitzer Park, every week.",
            visibility: .public,
            type: .football,
            ownerName: "Marta",
            memberCount: 34,
            role: .member,
            hasUnread: true,
            lastMessageHoursAgo: 1,
            createdDaysAgo: 120,
            roster: [("Marta", .owner), ("Jonas", .admin), ("Ayşe", .member), ("Dev", .member)]
        ),
        Template(
            id: runnersID,
            name: "Tempelhof Runners",
            description: "Easy loops on the old airfield. Nobody gets dropped.",
            visibility: .public,
            type: .running,
            ownerName: "Aiko",
            memberCount: 12,
            role: .admin,
            lastMessageHoursAgo: 26,
            createdDaysAgo: 60,
            roster: [("Aiko", .owner), ("Sam", .member), ("Noor", .member)]
        ),
        Template(
            id: padelID,
            name: "Sunday Padel Crew",
            description: "Two courts booked most Sundays. Rackets to borrow.",
            visibility: .private,
            type: .padel,
            ownerName: AppBranding.Groups.Create.mockOwnerName,
            memberCount: 6,
            role: .owner,
            lastMessageHoursAgo: 72,
            createdDaysAgo: 30,
            roster: [("Tom", .admin), ("Ines", .member), ("Luca", .member), ("Priya", .banned)]
        ),
        Template(
            id: basketballID,
            name: "Berlin Basketball",
            description: "Pickup games across the city, all levels.",
            visibility: .public,
            type: .basketball,
            ownerName: "Dev",
            memberCount: 58,
            createdDaysAgo: 200,
            roster: [("Dev", .owner), ("Marta", .member)]
        ),
        Template(
            id: volleyID,
            name: "Spree Volley",
            description: "Beach volleyball by the river.",
            visibility: .public,
            type: .volleyball,
            ownerName: "Luca",
            memberCount: 12,
            maxMembers: 12,
            createdDaysAgo: 10,
            roster: [("Luca", .owner), ("Ayşe", .member)]
        ),
        Template(
            id: climbingID,
            name: "Climbing Buddies",
            description: "Bouldering after work, invite only.",
            visibility: .private,
            type: .climbing,
            ownerName: "Noor",
            memberCount: 9,
            createdDaysAgo: 45,
            roster: [("Noor", .owner), ("Priya", .member)]
        ),
    ]

    private static let secondsPerHour = 3600.0
    private static let secondsPerDay = 86_400.0
    /// Marta wrote first, two weeks ago.
    private static let conversationAgeDays = 14.0

    static func make(now: Date) -> [SportGroup] {
        templates.map { makeGroup($0, now: now) } + [martaConversation(now: now)]
    }

    private static func makeGroup(_ template: Template, now: Date) -> SportGroup {
        let joinedAt = now.addingTimeInterval(-template.createdDaysAgo * secondsPerDay / 2)
        return SportGroup(
            id: template.id,
            name: template.name,
            description: template.description,
            visibility: template.visibility,
            type: template.type,
            ownerName: template.ownerName,
            memberCount: template.memberCount,
            maxMembers: template.maxMembers,
            lastMessageId: template.lastMessageHoursAgo.map { _ in MockChatFixtures.newestMessageID(for: template.id) },
            lastMessageAt: template.lastMessageHoursAgo.map { now.addingTimeInterval(-$0 * secondsPerHour) },
            createdAt: now.addingTimeInterval(-template.createdDaysAgo * secondsPerDay),
            membership: template.role.map {
                GroupMembership(role: $0,
                                joinedAt: joinedAt,
                                lastReadMessageId: template.hasUnread
                                    ? MockChatFixtures.lastReadMessageID(for: template.id)
                                    : MockChatFixtures.newestMessageID(for: template.id),
                                hasUnread: template.hasUnread)
            }
        )
    }

    /// The fixture conversation: Marta started it two weeks ago, and her last line (`MockChatFixtures`) is unread.
    private static func martaConversation(now: Date) -> SportGroup {
        let started = now.addingTimeInterval(-conversationAgeDays * secondsPerDay)
        let membership = GroupMembership(role: .member,
                                         joinedAt: started,
                                         lastReadMessageId: MockChatFixtures.lastReadMessageID(for: martaConversationID),
                                         hasUnread: true)
        return conversation(with: conversationCounterpart,
                            startedBy: conversationCounterpart.displayName,
                            at: started,
                            membership: membership,
                            lastMessageId: MockChatFixtures.newestMessageID(for: martaConversationID),
                            lastMessageAt: now.addingTimeInterval(-MockChatFixtures.conversationLastMessageAge))
    }

    /// A direct conversation as the backend shapes one: under `directConversationID(for:)`, named after the other
    /// person, private, two of two, no powers, `member` on the caller's side; `ownerName` is whoever started it. The
    /// fixture with Marta and the ones `MockGroupRepository.startDirect(with:name:)` creates both come from here.
    static func conversation(with counterpart: Counterpart,
                             startedBy ownerName: String,
                             at createdAt: Date,
                             membership: GroupMembership,
                             lastMessageId: String? = nil,
                             lastMessageAt: Date? = nil) -> SportGroup {
        SportGroup(id: directConversationID(for: counterpart.userId),
                   name: counterpart.displayName,
                   visibility: .private,
                   ownerName: ownerName,
                   memberCount: 2,
                   maxMembers: 2,
                   membersCanCreateEvents: false,
                   membersCanInvite: false,
                   lastMessageId: lastMessageId,
                   lastMessageAt: lastMessageAt,
                   createdAt: createdAt,
                   membership: membership,
                   kind: .direct,
                   counterpart: counterpart)
    }

    /// The other members of a group (never the caller), oldest first; banned rows included. A conversation's roster is
    /// the other person.
    static func roster(for groupID: String, now: Date) -> [GroupMember] {
        if groupID == martaConversationID {
            return [GroupMember(userId: conversationCounterpart.userId,
                                displayName: conversationCounterpart.displayName,
                                role: .member,
                                joinedAt: now.addingTimeInterval(-conversationAgeDays * secondsPerDay))]
        }
        guard let template = templates.first(where: { $0.id == groupID }) else { return [] }
        let createdAt = now.addingTimeInterval(-template.createdDaysAgo * secondsPerDay)
        return template.roster.enumerated().map { index, entry in
            GroupMember(userId: memberID(for: entry.name),
                        displayName: entry.name,
                        role: entry.role,
                        joinedAt: createdAt.addingTimeInterval(Double(index) * secondsPerDay))
        }
    }

    static func memberID(for name: String) -> String {
        "mock-user-\(name.lowercased())"
    }

    /// The direct conversation with a person is a private two-member group of kind `direct` under this id, so the
    /// fixture conversation and the ones `MockGroupRepository.startDirect(with:name:)` creates agree.
    static func directConversationID(for userID: String) -> String {
        "mock-dm-" + userID
    }

    /// The badge a mock event hosted in one of these groups carries; `nil` for an unknown id.
    static func ref(for groupID: String) -> EventGroupRef? {
        templates.first { $0.id == groupID }.map {
            EventGroupRef(id: $0.id, name: $0.name, visibility: $0.visibility, isDeleted: false)
        }
    }
}
