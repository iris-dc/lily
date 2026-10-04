import Foundation

/// Tournaments boundary. Reads answer the detail (entries, matches, standings) or the list items; every write answers
/// what the backend now holds. Failures arrive as `AppError`, ready for the popup.
protocol TournamentRepository {
    /// `.upcoming` is public tournaments in registration, soonest first, with the caller's coarse position for the
    /// statistics; `.mine` every tournament whose room the caller is in; `.group` a group's, all statuses but cancelled.
    func tournaments(in scope: TournamentScope, near position: Coordinate?) async throws -> [Tournament]
    /// Throws `AppError.tournamentNotFound` when it is gone, and for a private tournament the caller may not see.
    func tournament(id: String) async throws -> TournamentDetail
    /// Creates the tournament for the caller, who organises it; repeating a create with the same
    /// `TournamentDraft.clientId` answers the same tournament instead of a second one.
    func create(_ draft: TournamentDraft) async throws -> TournamentDetail
    /// The organiser's edit; after the start only the name, description and place may change.
    func update(id: String, _ draft: TournamentDraft) async throws -> TournamentDetail
    /// Enters the caller: alone (`teamName` ignored), or as the captain of a team with that name.
    func join(id: String, teamName: String?) async throws -> TournamentEntry
    func joinTeam(id: String, entryID: String) async throws -> TournamentEntry
    /// The player leaves, or their captain or the organiser removes them; `nil` when the entry emptied and is gone.
    func leave(id: String, entryID: String, userID: String) async throws -> TournamentEntry?
    /// The organiser removes a whole entry while registration is open.
    func removeEntry(id: String, entryID: String) async throws
    /// The organiser draws the matches; a replay on a started tournament answers its current detail.
    func start(id: String) async throws -> TournamentDetail
    func report(id: String, matchID: String, scoreA: Int, scoreB: Int) async throws -> TournamentDetail
    func confirm(id: String, matchID: String) async throws -> TournamentDetail
    func dispute(id: String, matchID: String) async throws -> TournamentDetail
    func walkover(id: String, matchID: String, winnerEntryID: String) async throws -> TournamentDetail
    func schedule(id: String, matchID: String, _ schedule: MatchSchedule) async throws -> TournamentMatch
    func cancel(id: String) async throws -> TournamentDetail
}
