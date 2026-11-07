import Foundation

nonisolated extension AppConfig {
    /// The caller's public name. Both values mirror Laurel's `profile.*` settings, so a name that passes here is stored
    /// as typed and the card's nudge shows exactly while the backend's default stands.
    enum DisplayName {
        /// `max-display-name-length`, counted in code points like `DynamoProfileService.normalize`.
        static let length = 1...32
        /// `default-display-name`: the name every profile starts with until the user picks one.
        static let backendDefault = "Player"
    }

    /// What the user writes about themselves, shown on their profile to other players.
    enum About {
        /// Laurel's `profile.max-bio-length`, counted in code points like `DynamoProfileService.normalizeBio`.
        static let maxLength = 300
    }

    /// The delete-account flow (the deletion contract).
    enum AccountDeletion {
        /// How often the locked sheet re-reads `GET /api/me` until a 401 or `USER_NOT_FOUND` settles the deletion.
        static let pollInterval: Duration = .seconds(2)
    }
}

nonisolated extension AppConfig.LaunchArguments {
    /// Makes the mock repositories serve deleted-flagged fixtures (a chat message whose sender is deleted, a past
    /// game hosted by a deleted user, a tournament entry of one), so tombstone rendering and the deleted-user glyph
    /// are walkable without a backend.
    static let mockDeletedUser = "-mock-deleted-user"
}
