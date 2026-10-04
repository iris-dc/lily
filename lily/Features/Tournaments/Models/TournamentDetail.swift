import Foundation

/// A tournament with everything on its screen: the entries in seed order, the matches by round and position once it
/// started, and the standings of a round robin in progress (empty for a bracket).
nonisolated struct TournamentDetail: Hashable, Codable, Sendable {
    private(set) var tournament: Tournament
    private(set) var entries: [TournamentEntry]
    private(set) var matches: [TournamentMatch]
    private(set) var standings: [TournamentStanding]

    init(tournament: Tournament,
         entries: [TournamentEntry] = [],
         matches: [TournamentMatch] = [],
         standings: [TournamentStanding] = []) {
        self.tournament = tournament
        self.entries = entries
        self.matches = matches
        self.standings = standings
    }

    var id: String { tournament.id }
    var myEntry: TournamentEntry? { tournament.myEntryId.flatMap(entry(id:)) }
    var registeredEntries: [TournamentEntry] { entries.filter(\.isRegistered) }

    func entry(id: String) -> TournamentEntry? {
        entries.first { $0.id == id }
    }

    func match(id: String) -> TournamentMatch? {
        matches.first { $0.id == id }
    }

    /// The entry the caller is in, from the roster rather than `myEntryId` (the mock's lists carry no caller).
    func entry(containing userID: String?) -> TournamentEntry? {
        entries.first { $0.contains(userID: userID) }
    }

    /// The other side of a match the user plays in: the match's entry not holding them; `nil` for a side not yet
    /// decided or a match of other people's.
    func opponent(in match: TournamentMatch, of userID: String?) -> TournamentEntry? {
        guard let mine = entry(containing: userID), match.contains(entryID: mine.id) else { return nil }
        return [match.entryAId, match.entryBId].compactMap { $0.flatMap(entry(id:)) }.first { $0.id != mine.id }
    }

    func replacing(tournament: Tournament) -> TournamentDetail {
        var copy = self
        copy.tournament = tournament
        return copy
    }

    func replacing(entries: [TournamentEntry]) -> TournamentDetail {
        var copy = self
        copy.entries = entries
        return copy
    }

    func replacing(matches: [TournamentMatch], standings: [TournamentStanding]) -> TournamentDetail {
        var copy = self
        copy.matches = matches
        copy.standings = standings
        return copy
    }

    /// One match as a route answered it (a schedule); the table is untouched, since no result moved.
    func replacing(match: TournamentMatch) -> TournamentDetail {
        var copy = self
        if let index = copy.matches.firstIndex(where: { $0.id == match.id }) {
            copy.matches[index] = match
        }
        return copy
    }
}
