import Foundation
import Testing
@testable import lily

struct BracketLayoutTests {
    @Test func roundTitlesCountBackFromTheFinal() {
        #expect(BracketLayout.roundTitle(round: 3, of: 3, format: .singleElimination) == "Final")
        #expect(BracketLayout.roundTitle(round: 2, of: 3, format: .singleElimination) == "Semi-finals")
        #expect(BracketLayout.roundTitle(round: 1, of: 3, format: .singleElimination) == "Quarter-finals")
        #expect(BracketLayout.roundTitle(round: 1, of: 4, format: .singleElimination) == "Round of 16")
        #expect(BracketLayout.roundTitle(round: 1, of: 6, format: .singleElimination) == "Round of 64")
        #expect(BracketLayout.roundTitle(round: 2, of: 5, format: .roundRobin) == "Round 2")
    }

    @Test func columnsGroupMatchesByRoundInPositionOrder() {
        let seeds = (1...5).map { "e\($0)" }
        let matches = TournamentSchedule.pairings(format: .singleElimination, seeds: seeds).shuffled().map {
            TournamentMatch(pairing: $0, tournamentId: "t")
        }
        let columns = BracketLayout.columns(of: matches)
        #expect(columns.count == 3 && BracketLayout.roundCount(of: matches) == 3)
        #expect(columns[0].map(\.position) == [1, 2, 3, 4] && columns[2].map(\.id) == ["r03p001"])
        #expect(BracketLayout.columns(of: []).isEmpty && BracketLayout.roundCount(of: []) == 0)
    }

    /// Round 1 cells take their own height; every later round takes two slots of the round before plus the gap, so a
    /// match sits level with the middle of its two feeders.
    @Test func slotHeightDoublesPerRound() {
        #expect(BracketLayout.slotHeight(round: 1, cellHeight: 72, spacing: 12) == 72)
        #expect(BracketLayout.slotHeight(round: 2, cellHeight: 72, spacing: 12) == 156)
        #expect(BracketLayout.slotHeight(round: 3, cellHeight: 72, spacing: 12) == 324)
    }

    /// 3 / 1 / 0 points, ranked by points, difference, scored, then seed; a walkover counts as a win without goals.
    @Test func standingsRankByPointsDifferenceScoredAndSeed() throws {
        let entries = (1...4).map { TournamentEntry.fixture(id: "e\($0)", name: "E\($0)", captainUserId: "u\($0)", seed: $0) }
        var matches = TournamentSchedule.pairings(format: .roundRobin, seeds: entries.map(\.id)).map {
            TournamentMatch(pairing: $0, tournamentId: "t")
        }
        // Round 1: e1-e4 3:1, e2-e3 2:2 (a draw); round 2: e1-e3 is a walkover for e3.
        matches[0] = matches[0].scored(3, 1, by: "u1", confirmed: true, at: .now)
        matches[1] = matches[1].scored(2, 2, by: "u2", confirmed: true, at: .now)
        matches[2] = matches[2].walkover(winnerEntryId: "e3", by: "org", at: .now)

        let table = RoundRobinStandings.compute(entries: entries, matches: matches)

        #expect(table.map(\.entryId) == ["e3", "e1", "e2", "e4"])
        let third = try #require(table.first { $0.entryId == "e3" })
        #expect(third.rank == 1 && third.points == 4 && third.played == 2 && third.won == 1 && third.drawn == 1)
        let first = try #require(table.first { $0.entryId == "e1" })
        #expect(first.points == 3 && first.scored == 3 && first.conceded == 1 && first.lost == 1)
        let fourth = try #require(table.first { $0.entryId == "e4" })
        #expect(fourth.rank == 4 && fourth.points == 0 && fourth.played == 1)
        #expect(RoundRobinStandings.compute(entries: entries, matches: []).allSatisfy { $0.points == 0 && $0.played == 0 })
    }
}
