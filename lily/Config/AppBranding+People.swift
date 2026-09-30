import Foundation

nonisolated extension AppBranding {
    /// Copy of a person's profile and of the rows that name people (rosters, participants, senders).
    enum People {
        static let sharedGroupsTitle = "Groups in common"
        static let noSharedGroups = "No groups in common yet"
        static let loadFailedTitle = "Couldn't load this profile"
        static let message = "Message"
        /// The caption of a conversation's row on Chats, where a group's says its size and type.
        static let directMessage = "Direct message"
        /// The caller's own row in any list of people; the one word `Groups.youSuffix` already uses.
        static let youLabel = Groups.youSuffix

        /// A person's name on a row: theirs, or theirs with "You" for the caller. The suffix is skipped when the name
        /// already is it (the mock names the caller "You").
        static func name(_ displayName: String, isSelf: Bool) -> String {
            guard isSelf, displayName != youLabel else { return displayName }
            return Groups.caption([displayName, youLabel])
        }
    }
}

nonisolated extension AppBranding.Events {
    /// The list of who joined a game, under its facts, and the chip on the host's row.
    static let participantsTitle = "Who's in"
    static let hostChip = "Host"
}
