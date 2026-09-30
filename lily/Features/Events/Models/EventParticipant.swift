import Foundation

/// The backend's `EventParticipant`: one person in a game, the host marked, as `GET /api/events/{id}/participants` lists
/// them (host first, then by join time).
nonisolated struct EventParticipant: Identifiable, Hashable, Codable, Sendable {
    let userId: String
    let displayName: String
    let joinedAt: Date
    let isHost: Bool

    var id: String { userId }
}
