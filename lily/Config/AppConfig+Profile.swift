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
}
