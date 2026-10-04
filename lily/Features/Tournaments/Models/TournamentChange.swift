import Foundation

/// The `tournament_changed` event on a tournament's room channel, after every write to the tournament itself: where
/// it stands and how many entries are in. The app refetches the detail; this says only that it moved.
nonisolated struct TournamentChange: Hashable, Codable, Sendable {
    let tournamentId: String
    let status: TournamentStatus
    let entryCount: Int
    let channelEpoch: Int
    let updatedAt: Date?

    init(tournamentId: String, status: TournamentStatus, entryCount: Int, channelEpoch: Int, updatedAt: Date? = nil) {
        self.tournamentId = tournamentId
        self.status = status
        self.entryCount = entryCount
        self.channelEpoch = channelEpoch
        self.updatedAt = updatedAt
    }
}
