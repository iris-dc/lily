import Foundation
import Testing
@testable import lily

/// `TournamentDetail.starting` and `settling` replay the backend's draw and results for the mock and the fake.
struct TournamentDetailProgressTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_600)
    private let organizer = "org"

    @Test func startingDrawsTheSharedPairingsFromTheRegisteredEntries() {
        let started = Self.bracket.starting(at: date)

        let expected = TournamentSchedule.pairings(format: .singleElimination, seeds: ["e1", "e2", "e3", "e4"])
            .map { TournamentMatch(pairing: $0, tournamentId: "t") }
        #expect(started.matches == expected, "the matches are the backend's pairings, under the tournament's id")
        #expect(started.tournament.status == .inProgress && started.tournament.startedAt == date)
        #expect(started.standings.isEmpty, "a bracket has no table")
    }

    @Test func startingARoundRobinSeedsAZeroTable() {
        let started = Self.league.starting(at: date)

        #expect(started.standings.map(\.entryId) == ["e1", "e2", "e3"], "ranked by seed while nothing was played")
        #expect(started.standings.map(\.rank) == [1, 2, 3])
        #expect(started.standings.allSatisfy { $0.played == 0 && $0.points == 0 })
    }

    @Test func startingSkipsWithdrawnEntries() {
        let withdrawn = TournamentEntry.fixture(id: "e4", name: "Gone", captainUserId: "p4", seed: 4, status: .withdrawn)
        let detail = Self.league.replacing(entries: Self.league.entries + [withdrawn])

        let started = detail.starting(at: date)

        #expect(started.matches.allSatisfy { !$0.contains(entryID: "e4") }, "a withdrawn entry is in no match")
        #expect(!started.standings.contains { $0.entryId == "e4" }, "and has no row in the table")
    }

    @Test func settlingAdvancesTheWinnerIntoTheNextSlot() throws {
        let started = Self.bracket.starting(at: date)
        let firstSemi = try #require(started.match(id: "r01p001"))
        let secondSemi = try #require(started.match(id: "r01p002"))

        let afterFirst = try settled("r01p001", 2, 1, in: started)
        let afterBoth = try settled("r01p002", 0, 3, in: afterFirst)

        #expect(afterFirst.match(id: "r02p001")?.entryAId == firstSemi.entryAId, "the first semi feeds slot A")
        #expect(afterFirst.match(id: "r02p001")?.entryBId == nil, "the other slot waits for its semi")
        #expect(afterBoth.match(id: "r02p001")?.entryBId == secondSemi.entryBId, "the second semi feeds slot B")
        #expect(afterBoth.tournament.status == .inProgress && afterBoth.tournament.winnerEntryId == nil)
    }

    @Test func settlingTheFinalCompletesTheBracketWithItsWinner() throws {
        let semis = try settled("r01p002", 0, 3, in: settled("r01p001", 2, 1, in: Self.bracket.starting(at: date)))
        let finalMatch = try #require(semis.match(id: "r02p001"))

        let completed = try settled("r02p001", 1, 0, in: semis)

        #expect(completed.tournament.status == .completed)
        #expect(completed.tournament.winnerEntryId == finalMatch.entryAId)
        #expect(completed.tournament.completedAt == date)
    }

    @Test func settlingARoundRobinRecomputesTheTableOnEveryResult() throws {
        let started = Self.league.starting(at: date)
        let match = try #require(started.match(id: "r01p001"))

        let settled = try settled("r01p001", 3, 1, in: started)

        let leader = try #require(settled.standings.first)
        #expect(leader.entryId == match.entryAId && leader.points == 3 && leader.played == 1)
        #expect(settled.standings.dropFirst().allSatisfy { $0.points == 0 })
        #expect(settled.tournament.status == .inProgress, "two matches are still to play")
    }

    @Test func settlingTheLastRoundRobinMatchCompletesWithTheLeader() throws {
        let twoPlayed = try settled("r02p001", 1, 0, in: settled("r01p001", 3, 1, in: Self.league.starting(at: date)))
        #expect(twoPlayed.tournament.status == .inProgress, "one match is still open")

        let completed = try settled("r03p001", 1, 1, in: twoPlayed)

        #expect(completed.tournament.status == .completed && completed.tournament.completedAt == date)
        #expect(completed.tournament.winnerEntryId == "e2", "level on points, the better difference leads")
        #expect(completed.tournament.winnerEntryId == completed.standings.first?.entryId)
    }

    @Test(arguments: [TournamentFormat.singleElimination, .roundRobin])
    func settlingADisputeSwapsTheMatchAndMovesNothingElse(_ format: TournamentFormat) throws {
        let started = Self.detail(format: format).starting(at: date)
        let match = try #require(started.match(id: "r01p001"))

        let disputed = started.settling(match.reporting(2, 1, by: "a-player", at: date).disputing(), at: date)

        #expect(disputed.match(id: "r01p001")?.isOpenDispute == true)
        #expect(disputed.standings == started.standings, "a dispute moves no points")
        #expect(disputed.tournament == started.tournament, "and completes nothing")
        #expect(disputed.matches.filter { $0.id != "r01p001" } == started.matches.filter { $0.id != "r01p001" },
                "no winner was placed in a next match")
    }

    @Test func settlingAMatchTheDetailDoesNotHoldChangesNothing() {
        let started = Self.bracket.starting(at: date)
        let stray = TournamentMatch(pairing: .init(id: "r09p001", round: 9, position: 1, entryAId: "e1", entryBId: "e2"),
                                    tournamentId: "t")

        #expect(started.settling(stray.recording(1, 0, by: organizer, at: date), at: date) == started)
    }

    private static let bracket = detail(format: .singleElimination)
    private static let league = detail(format: .roundRobin)

    private static func detail(format: TournamentFormat) -> TournamentDetail {
        let count = format == .singleElimination ? 4 : 3
        let entries = (1...count).map { seed in
            TournamentEntry.fixture(id: "e\(seed)", name: "Player \(seed)", captainUserId: "p\(seed)", seed: seed)
        }
        let tournament = Tournament.fixture(format: format, entryCount: count, allowsDraws: true, organizerUserId: "org")
        return .fixture(tournament: tournament, entries: entries)
    }

    private func settled(_ id: String,
                         _ scoreA: Int,
                         _ scoreB: Int,
                         in detail: TournamentDetail) throws -> TournamentDetail {
        let match = try #require(detail.match(id: id))
        return detail.settling(match.recording(scoreA, scoreB, by: organizer, at: date), at: date)
    }
}
