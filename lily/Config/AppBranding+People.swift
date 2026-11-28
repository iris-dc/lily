import Foundation

nonisolated extension AppBranding {
    /// Copy of a person's profile and of the rows that name people (rosters, participants, senders).
    enum People {
        static var sharedGroupsTitle: String { localized("Groups in common") }
        static var noSharedGroups: String { localized("No groups in common yet") }
        /// The games both joined and the tournaments whose room both are in, the latest first.
        static var sharedEventsTitle: String { localized("Games together") }
        static var noSharedEvents: String { localized("No games together yet") }
        static var sharedTournamentsTitle: String { localized("Tournaments together") }
        static var noSharedTournaments: String { localized("No tournaments together yet") }
        static var loadFailedTitle: String { localized("Couldn't load this profile") }
        /// The profile's button: a verb, where the composer's placeholder `Chat.placeholder` (key "Message") is the noun.
        static var message: String { localized("Message (verb)") }
        /// The caption of a conversation's row on Chats, where a group's says its size and type.
        static var directMessage: String { localized("Direct message") }
        /// The caller's own row in any list of people; the one word `Groups.youSuffix` already uses.
        static var youLabel: String { Groups.youSuffix }

        /// A person's name on a row: theirs, or theirs with "You" for the caller. The suffix is skipped when the name
        /// already is it (the mock names the caller "You").
        static func name(_ displayName: String, isSelf: Bool) -> String {
            guard isSelf, displayName != youLabel else { return displayName }
            return Groups.caption([displayName, youLabel])
        }

        /// The detail screens' sections and their People card: the one row that leads to the full list.
        static var peopleSection: String { localized("People") }
        static var aboutSection: String { localized("About") }
        static var detailsSection: String { AppBranding.Create.eventDetails }
        static var hostingRow: String { localized("Hosting") }
        static var goingRow: String { localized("Going") }
        static var organisedByRow: String { localized("Organised by") }
        static var nobodyGoingYet: String { localized("Nobody has joined yet") }

        static func hostedBy(name: String) -> String {
            localized("Hosted by \(name)")
        }

        static func organisedBy(name: String) -> String {
            localized("Organised by \(name)")
        }

        /// The People card's count line on an event: who is in besides the host.
        static func going(_ count: Int) -> String {
            localized("\(count) going")
        }
    }
}

nonisolated extension AppBranding.Events {
    /// The list of who joined a game, under its facts, and the chip on the host's row.
    static var participantsTitle: String { localized("Who's in") }
    static var hostChip: String { localized("Host") }
}
