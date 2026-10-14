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
        #expect(columns.count == 3)
        #expect(columns[0].map(\.position) == [1, 2, 3, 4] && columns[2].map(\.id) == ["r03p001"])
        #expect(BracketLayout.columns(of: []).isEmpty)
    }

    /// Round 1 cells take their own height; every later round takes two slots of the round before plus the gap, so a
    /// match sits level with the middle of its two feeders.
    @Test func slotHeightDoublesPerRound() {
        #expect(BracketLayout.slotHeight(round: 1, cellHeight: 72, spacing: 12) == 72)
        #expect(BracketLayout.slotHeight(round: 2, cellHeight: 72, spacing: 12) == 156)
        #expect(BracketLayout.slotHeight(round: 3, cellHeight: 72, spacing: 12) == 324)
    }
}
