import Foundation

/// Decodes the backend's `UserProfile`: another person as the caller may see them, with the groups the two share (never
/// a group the caller is not in; the caller's own id answers their own groups).
nonisolated struct UserProfile: Hashable, Codable, Sendable {
    let userId: String
    let displayName: String
    let sharedGroups: [GroupSummary]
}
