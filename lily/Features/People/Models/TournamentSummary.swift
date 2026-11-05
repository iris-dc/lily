import Foundation

/// The backend's `TournamentSummary`: a tournament as a profile's "Tournaments together" row shows it, enough for the
/// row and the link.
nonisolated struct TournamentSummary: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let type: EventType
    let status: TournamentStatus
    let startsAt: Date

    init(id: String, name: String, type: EventType, status: TournamentStatus, startsAt: Date) {
        self.id = id
        self.name = name
        self.type = type
        self.status = status
        self.startsAt = startsAt
    }

    /// A tournament the caller holds in full, reduced to its summary (the mock profiles).
    init(_ tournament: Tournament) {
        self.init(id: tournament.id,
                  name: tournament.name,
                  type: tournament.type,
                  status: tournament.status,
                  startsAt: tournament.startsAt)
    }

    /// "Football · Completed · 4 Oct 2026".
    var caption: String {
        AppBranding.Groups.caption([type.displayName, status.displayName, startsAt.formatted(LilyTheme.DateStyles.date)])
    }

    /// The destination the row pushes: the detail fetches the tournament, the summary being no preview of it.
    var destination: TournamentDestination {
        TournamentDestination(id: id, name: name)
    }
}
