import Foundation

/// The other participant of a direct conversation, as the caller sees them; on the wire only with `kind == direct`.
nonisolated struct Counterpart: Hashable, Codable, Sendable {
    let userId: String
    let displayName: String

    /// Their profile, where a conversation's info button (`.fromChat`) and a conversation pushed as a group lead.
    func profile(context: GroupDetailContext = .standalone) -> UserProfileDestination {
        UserProfileDestination(userId: userId, displayName: displayName, context: context)
    }
}
