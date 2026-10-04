import Foundation

/// The `tournamentInvite` payload of a `tournament_invite` item: who asked the caller into which tournament, what kind
/// of tournament it is, and where the answer stands.
nonisolated struct TournamentInvitePayload: Hashable, Codable, Sendable, InviteAnswer {
    let tournamentId: String
    let tournamentName: String
    let type: EventType
    let format: TournamentFormat
    /// One means the accept enters the caller; more means they pick or name a team on the detail.
    let teamSize: Int
    let inviterUserId: String
    let inviterName: String
    let status: InviteStatus
    let expiresAt: Date
    /// Present once the caller accepted or declined.
    let respondedAt: Date?

    init(tournamentId: String,
         tournamentName: String,
         type: EventType,
         format: TournamentFormat,
         teamSize: Int,
         inviterUserId: String,
         inviterName: String,
         status: InviteStatus = .pending,
         expiresAt: Date,
         respondedAt: Date? = nil) {
        self.tournamentId = tournamentId
        self.tournamentName = tournamentName
        self.type = type
        self.format = format
        self.teamSize = teamSize
        self.inviterUserId = inviterUserId
        self.inviterName = inviterName
        self.status = status
        self.expiresAt = expiresAt
        self.respondedAt = respondedAt
    }

    var isTeam: Bool { teamSize > 1 }
    /// "Football · Single elimination · Teams of 5".
    var details: String { AppBranding.Tournaments.inviteDetails(type: type, format: format, teamSize: teamSize) }

    func responding(_ status: InviteStatus, at date: Date) -> TournamentInvitePayload {
        TournamentInvitePayload(tournamentId: tournamentId,
                                tournamentName: tournamentName,
                                type: type,
                                format: format,
                                teamSize: teamSize,
                                inviterUserId: inviterUserId,
                                inviterName: inviterName,
                                status: status,
                                expiresAt: expiresAt,
                                respondedAt: date)
    }
}

/// The `matchReminder` payload of a `match_reminder` item: a snapshot of the caller's match an hour before it starts.
nonisolated struct MatchReminderPayload: Hashable, Codable, Sendable {
    let tournamentId: String
    let tournamentName: String
    let matchId: String
    let opponentName: String
    let scheduledAt: Date
    /// Absent when the match was scheduled without a place.
    let locationName: String?

    init(tournamentId: String,
         tournamentName: String,
         matchId: String,
         opponentName: String,
         scheduledAt: Date,
         locationName: String? = nil) {
        self.tournamentId = tournamentId
        self.tournamentName = tournamentName
        self.matchId = matchId
        self.opponentName = opponentName
        self.scheduledAt = scheduledAt
        self.locationName = locationName
    }

    /// The tournament's detail with this match's sheet raised.
    var destination: TournamentDestination {
        TournamentDestination(id: tournamentId, name: tournamentName, matchID: matchId)
    }
}
