import Foundation

nonisolated extension AppConfig {
    /// Profiles and direct conversations.
    enum People {
        /// The backend's `conversations.max-per-user`; the copy of `CONVERSATION_LIMIT` names it.
        static let maxConversations = 200
        /// Laurel's `profile.max-shared-history`: the most games, and the most tournaments, a profile lists; the mock caps
        /// its lists the same way.
        static let maxSharedHistory = 20
    }
}

nonisolated extension AppConfig.API.Paths {
    /// `POST {userId}` starts (or answers again) the direct conversation with a person.
    static let conversations = "/api/conversations"

    /// `GET` answers a person's display name and bio, and the groups, games and tournaments the caller shares with them.
    static func user(id: String) -> String {
        "/api/users/\(id)"
    }
}
