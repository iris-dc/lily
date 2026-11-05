import Foundation

/// Decodes the backend's `UserProfile`: another person as the caller may see them, with what the two share (never a
/// group, game or tournament the caller is not in; the caller's own id answers their own). The history arrays default
/// to empty for a backend that does not send them yet.
nonisolated struct UserProfile: Hashable, Codable, Sendable {
    let userId: String
    let displayName: String
    /// What they wrote about themselves; absent until they did.
    let bio: String?
    let sharedGroups: [GroupSummary]
    /// The games both joined, past or upcoming, the latest first.
    let sharedEvents: [EventSummary]
    /// The tournaments whose room both are in, the latest first; a deleted or cancelled one is never listed.
    let sharedTournaments: [TournamentSummary]

    init(userId: String,
         displayName: String,
         bio: String? = nil,
         sharedGroups: [GroupSummary],
         sharedEvents: [EventSummary] = [],
         sharedTournaments: [TournamentSummary] = []) {
        self.userId = userId
        self.displayName = displayName
        self.bio = bio
        self.sharedGroups = sharedGroups
        self.sharedEvents = sharedEvents
        self.sharedTournaments = sharedTournaments
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        displayName = try container.decode(String.self, forKey: .displayName)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        sharedGroups = try container.decode([GroupSummary].self, forKey: .sharedGroups)
        sharedEvents = try container.decodeIfPresent([EventSummary].self, forKey: .sharedEvents) ?? []
        sharedTournaments = try container.decodeIfPresent([TournamentSummary].self, forKey: .sharedTournaments) ?? []
    }
}
