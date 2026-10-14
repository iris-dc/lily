import Foundation

/// A tournament with everything on its screen: the entries in seed order, the matches by round and position once it
/// started, and the standings of a round robin in progress (empty for a bracket).
nonisolated struct TournamentDetail: Identifiable, Hashable, Codable, Sendable {
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
    /// The entries still in, in seed order. The wire delivers them so and `TournamentContractTests` pins it; the
    /// sort here is the one guard for a mock or a local edit that reorders them.
    var registeredEntries: [TournamentEntry] { entries.filter(\.isRegistered).sorted { $0.seed < $1.seed } }

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

    /// The start as the backend's transaction makes it: the matches drawn from the registered entries through the
    /// shared pairings, a round robin's table seeded at zero, the tournament under way. The refusals (who starts, the
    /// status, the entry count) stay with the repositories.
    func starting(at date: Date) -> TournamentDetail {
        let seeds = registeredEntries.map(\.id)
        let matches = TournamentSchedule.pairings(format: tournament.format, seeds: seeds).map {
            TournamentMatch(pairing: $0, tournamentId: id)
        }
        return replacing(tournament: tournament.starting(at: date))
            .replacing(matches: matches, standings: table(for: matches))
    }

    /// A result as the backend's transaction settles it: the match swapped in, a round robin's table recomputed, a
    /// decided match's winner placed in the next match of a bracket, and the tournament completed on a bracket's final
    /// or a round robin's last decided match, with the table's leader as winner. A dispute, or a report that stands
    /// unconfirmed, only swaps; a match the detail does not hold changes nothing.
    func settling(_ match: TournamentMatch, at date: Date) -> TournamentDetail {
        guard matches.contains(where: { $0.id == match.id }) else { return self }
        let advanced = advancing(match, in: replacing(match: match).matches)
        let settled = replacing(matches: advanced, standings: table(for: advanced))
        guard match.isDecided, let champion = settled.champion else { return settled }
        return settled.replacing(tournament: settled.tournament.completing(winnerEntryId: champion, at: date))
    }

    /// A decided match's winner stands in the next match of a bracket; a round robin's matches feed none.
    private func advancing(_ match: TournamentMatch, in matches: [TournamentMatch]) -> [TournamentMatch] {
        guard match.isDecided, let winner = match.winnerEntryId, let nextID = match.nextMatchId,
              let slot = match.nextSlot, let next = matches.firstIndex(where: { $0.id == nextID }) else { return matches }
        var matches = matches
        matches[next] = matches[next].placing(winner, in: slot)
        return matches
    }

    private func table(for matches: [TournamentMatch]) -> [TournamentStanding] {
        tournament.format == .roundRobin ? RoundRobinStandings.compute(entries: registeredEntries, matches: matches) : []
    }

    /// The winner once nothing is left to play: the final's in a bracket, the table's leader in a round robin.
    private var champion: String? {
        guard matches.allSatisfy(\.isDecided) else { return nil }
        return switch tournament.format {
        case .singleElimination: matches.first { $0.nextMatchId == nil }?.winnerEntryId
        case .roundRobin: standings.first?.entryId
        }
    }
}
