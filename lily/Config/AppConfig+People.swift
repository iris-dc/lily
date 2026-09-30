import Foundation

nonisolated extension AppConfig {
    /// Profiles and direct conversations.
    enum People {
        /// The backend's `conversations.max-per-user`; the copy of `CONVERSATION_LIMIT` names it.
        static let maxConversations = 200
    }
}

nonisolated extension AppConfig.API.Paths {
    /// `POST {userId}` starts (or answers again) the direct conversation with a person.
    static let conversations = "/api/conversations"

    /// `GET` answers a person's display name and the groups the caller shares with them.
    static func user(id: String) -> String {
        "/api/users/\(id)"
    }
}
