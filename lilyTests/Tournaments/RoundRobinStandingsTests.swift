import Foundation
import Testing
@testable import lily

/// The mock's table, ranked as Laurel ranks it: points, then score difference, then scored, then seed.
struct RoundRobinStandingsTests {
    private static let entries = ["a", "b", "c", "d"].enumerated().map { index, letter in
        TournamentEntry.fixture(id: letter, name: "Team \(letter)", captainUserId: "cap-\(letter)", seed: index + 1)
    }

    /// Win 3, draw 1, loss 0; a walkover is a win without goals.
    @Test func standingsRankByPointsDifferenceScoredAndSeed() throws {
        let entries = (1...4).map { TournamentEntry.fixture(id: "e\($0)", name: "E\($0)", captainUserId: "u\($0)", seed: $0) }
        var matches = TournamentSchedule.pairings(format: .roundRobin, seeds: entries.map(\.id)).map {
            TournamentMatch(pairing: $0, tournamentId: "t")
        }
        // Round 1: e1-e4 3:1, e2-e3 2:2 (a draw); round 2: e1-e3 is a walkover for e3.
        matches[0] = matches[0].recording(3, 1, by: "u1", at: .now)
        matches[1] = matches[1].recording(2, 2, by: "u2", at: .now)
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

    /// Laurel's `byGoals` case.
    @Test func levelOnPointsAndDifferenceMoreScoredRanksFirst() {
        let matches = [Self.played("a", "d", 2, 1, position: 1),
                       Self.played("b", "c", 1, 0, position: 2),
                       Self.played("c", "d", 1, 1, position: 3)]

        let table = RoundRobinStandings.compute(entries: Self.entries, matches: matches)

        #expect(table.map(\.entryId) == ["a", "b", "d", "c"])
        #expect(table.map(\.rank) == [1, 2, 3, 4])
        #expect(table.map(\.points) == [3, 3, 1, 1])
        #expect(table.map { $0.scored - $0.conceded } == [1, 1, -1, -1])
        #expect(table.map(\.scored) == [2, 1, 2, 1])
    }

    /// Laurel's `bySeed` case.
    @Test func levelOnEverythingTheBetterSeedRanksFirst() {
        let matches = [Self.played("a", "d", 1, 0, position: 1),
                       Self.played("b", "c", 1, 0, position: 2),
                       Self.played("c", "d", 1, 1, position: 3)]

        let table = RoundRobinStandings.compute(entries: Self.entries, matches: matches)

        #expect(table.map(\.entryId) == ["a", "b", "c", "d"])
        #expect(table.map(\.points) == [3, 3, 1, 1])
        #expect(table.map { $0.scored - $0.conceded } == [1, 1, -1, -1])
        #expect(table.map(\.scored) == [1, 1, 1, 1])
    }

    @Test func levelOnPointsTheDifferenceDecides() {
        let matches = [Self.played("a", "d", 3, 0, position: 1),
                       Self.played("b", "c", 1, 0, position: 2)]

        let table = RoundRobinStandings.compute(entries: Self.entries, matches: matches)

        #expect(table.map(\.entryId) == ["a", "b", "c", "d"])
        #expect(table.map(\.points) == [3, 3, 0, 0])
        #expect(table.map { $0.scored - $0.conceded } == [3, 1, -1, -3])
    }

    private static func played(_ sideA: String,
                               _ sideB: String,
                               _ scoreA: Int,
                               _ scoreB: Int,
                               position: Int) -> TournamentMatch {
        TournamentMatch(id: "r01p00\(position)",
                        tournamentId: "t",
                        round: 1,
                        position: position,
                        entryAId: sideA,
                        entryBId: sideB)
            .recording(scoreA, scoreB, by: "org", at: .now)
    }
}
