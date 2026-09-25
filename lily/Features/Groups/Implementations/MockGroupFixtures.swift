import Foundation

/// The six groups of a mock run: three the caller is in (as member, admin and owner), one to join, one that is full,
/// and one private group reachable only through `AppConfig.Groups.mockInviteCode`.
nonisolated enum MockGroupFixtures {
    static let kickersID = "mock-group-kickers"
    static let runnersID = "mock-group-runners"
    static let padelID = "mock-group-padel"
    static let basketballID = "mock-group-basketball"
    static let volleyID = "mock-group-volley"
    static let climbingID = "mock-group-climbing"

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

    static func make(now: Date) -> [SportGroup] {
        templates.map { template in
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
    }

    /// The other members of a group (never the caller), oldest first; banned rows included.
    static func roster(for groupID: String, now: Date) -> [GroupMember] {
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

    /// The badge a mock event hosted in one of these groups carries; `nil` for an unknown id.
    static func ref(for groupID: String) -> EventGroupRef? {
        templates.first { $0.id == groupID }.map {
            EventGroupRef(id: $0.id, name: $0.name, visibility: $0.visibility, isDeleted: false)
        }
    }
}
