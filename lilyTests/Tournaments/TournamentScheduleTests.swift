import Foundation
import Testing
@testable import lily

/// The pairing fixtures in `lilyTests/Fixtures/pairings` are shared with Laurel and pin the mock's draw to the backend's, field for field.
struct TournamentScheduleTests {
    /// `{format, seeds, matches}` as the files hold it; the matches decode straight into the schedule's pairings.
    private struct Fixture: Decodable {
        let format: TournamentFormat
        let seeds: [String]
        let matches: [TournamentSchedule.Pairing]
    }

    private static let fixtureNames = ["single-elimination-2", "single-elimination-5", "single-elimination-8",
                                       "round-robin-4", "round-robin-5"]

    @Test(arguments: fixtureNames)
    func theScheduleReproducesTheFixture(name: String) throws {
        let fixture = try Self.fixture(named: name)
        let pairings = TournamentSchedule.pairings(format: fixture.format, seeds: fixture.seeds)
        #expect(pairings == fixture.matches, "\(name)")
    }

    /// Eight seeds: the standard bracket order 1-8, 4-5, 2-7, 3-6; three rounds with the final pointing nowhere.
    @Test func eightSeedsDrawTheStandardBracket() {
        let seeds = (1...8).map { "e\($0)" }
        let pairings = TournamentSchedule.pairings(format: .singleElimination, seeds: seeds)
        #expect(pairings.count == 7 && pairings.map(\.round) == [1, 1, 1, 1, 2, 2, 3])
        let firstRound = pairings.prefix(4).map { ($0.entryAId ?? "") + "-" + ($0.entryBId ?? "") }
        #expect(firstRound == ["e1-e8", "e4-e5", "e2-e7", "e3-e6"])
        #expect(pairings[0].nextMatchId == "r02p001" && pairings[0].nextSlot == .a && pairings[1].nextSlot == .b)
        #expect(pairings[6].id == "r03p001" && pairings[6].nextMatchId == nil && pairings.allSatisfy { $0.status == .pending })
    }

    /// Five seeds: three byes to the top seeds, each already standing in its second-round match.
    @Test func byesGoToTheTopSeedsAndAdvanceAtOnce() {
        let pairings = TournamentSchedule.pairings(format: .singleElimination, seeds: (1...5).map { "e\($0)" })
        let byes = pairings.filter { $0.status == .bye }
        #expect(byes.map(\.entryAId) == ["e1", "e2", "e3"] && byes.allSatisfy { $0.winnerEntryId == $0.entryAId })
        let semiFinalOne = pairings.first { $0.id == "r02p001" }
        #expect(semiFinalOne?.entryAId == "e1" && semiFinalOne?.entryBId == nil)
        let semiFinalTwo = pairings.first { $0.id == "r02p002" }
        #expect(semiFinalTwo?.entryAId == "e2" && semiFinalTwo?.entryBId == "e3")
    }

    /// Everyone meets everyone once; an odd count sits one out per round.
    @Test func roundRobinMeetsEveryoneOnce() {
        for count in 3...12 {
            let seeds = (1...count).map { "e\($0)" }
            let pairings = TournamentSchedule.pairings(format: .roundRobin, seeds: seeds)
            #expect(pairings.count == count * (count - 1) / 2, "\(count) entries")
            let pairs = Set(pairings.map { [$0.entryAId ?? "", $0.entryBId ?? ""].sorted().joined(separator: "-") })
            #expect(pairs.count == pairings.count, "no pair twice for \(count)")
            #expect(pairings.map(\.round).max() == (count.isMultiple(of: 2) ? count - 1 : count), "rounds for \(count)")
        }
    }

    @Test func matchIdsPadRoundsToTwoAndPositionsToThreeDigits() {
        #expect(TournamentSchedule.matchID(round: 1, position: 3) == "r01p003")
        #expect(TournamentSchedule.matchID(round: 12, position: 100) == "r12p100")
    }

    /// The backend refuses a start with fewer than two entries, so the draw never has to handle one seed or none.
    @Test func fewerThanTwoSeedsDrawNothing() {
        #expect(TournamentSchedule.pairings(format: .singleElimination, seeds: []).isEmpty)
        #expect(TournamentSchedule.pairings(format: .singleElimination, seeds: ["a"]).isEmpty)
        #expect(TournamentSchedule.pairings(format: .roundRobin, seeds: []).isEmpty)
        #expect(TournamentSchedule.pairings(format: .roundRobin, seeds: ["a"]).isEmpty)
    }

    /// The synchronized group flattens the fixtures folder into the bundle root, which `TestFixtureFiles` looks at first.
    private static func fixture(named name: String) throws -> Fixture {
        let url = try #require(TestFixtureFiles.url(forResource: name, withExtension: "json", subdirectory: "pairings"),
                               "fixture \(name).json missing from the test bundle")
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }
}
