import Foundation
import Testing
@testable import lily

/// A caller's own standing result, confirmation or walkover sent again is a repeat the mock answers with the detail, as
/// the backend does; any other write meets the usual refusal, and a dispute is never a repeat.
@MainActor
struct MockTournamentReplayTests {
    private static let leagueID = "mock-tournament-league"
    private let identity = FakeIdentityProvider(currentUserID: "mock-apple")
    private let logger = SpyLogger()
    private let repository: MockTournamentRepository

    init() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let groups = MockGroupRepository(identity: identity, logger: logger, now: { now })
        repository = MockTournamentRepository(groups: groups, identity: identity, logger: logger, now: { now })
    }

    @Test func aSameCallerRepeatOfAResultAnswersTheDetail() async throws {
        let id = try await startedLeague().id
        let first = try await repository.report(id: id, matchID: "r01p001", scoreA: 3, scoreB: 1)
        #expect(first.match(id: "r01p001")?.status == .confirmed, "the organiser's score stands at once")

        let repeated = try await repository.report(id: id, matchID: "r01p001", scoreA: 3, scoreB: 1)
        #expect(repeated == first, "the same match and the same table: nothing moved")
        #expect(logger.hasLine(in: .tournaments, mentioning: "r01p001", "repeated"))
        await #expect(throws: AppError.matchNotReady, "another score is no repeat") {
            try await repository.report(id: id, matchID: "r01p001", scoreA: 3, scoreB: 2)
        }
    }

    @Test func aSameCallerRepeatOfAConfirmAnswersTheDetail() async throws {
        let id = MockTournamentFixtures.tableTennisID
        let theirs = MockTournamentFixtures.tableTennisReport.matchID
        let first = try await repository.confirm(id: id, matchID: theirs)
        let settled = try #require(first.match(id: theirs))
        #expect(settled.status == .confirmed && settled.confirmedBy == "mock-apple")

        let repeated = try await repository.confirm(id: id, matchID: theirs)
        #expect(repeated == first)
        #expect(logger.hasLine(in: .tournaments, mentioning: theirs, "repeated"))
        let recorded = try #require(callersRoundOneMatch(in: first))
        #expect(recorded.status == .confirmed && recorded.confirmedBy != "mock-apple", "the organiser recorded it")
        await #expect(throws: AppError.matchNotReady, "confirmed by another hand is no repeat") {
            try await repository.confirm(id: id, matchID: recorded.id)
        }
    }

    @Test func aSameCallerRepeatOfAWalkoverAnswersTheDetail() async throws {
        let started = try await startedLeague()
        let match = try #require(started.match(id: "r01p001"))
        let winner = try #require(match.entryAId)
        let loser = try #require(match.entryBId)
        let first = try await repository.walkover(id: started.id, matchID: match.id, winnerEntryID: winner)
        #expect(first.match(id: match.id)?.status == .walkover)

        let repeated = try await repository.walkover(id: started.id, matchID: match.id, winnerEntryID: winner)
        #expect(repeated == first)
        #expect(logger.hasLine(in: .tournaments, mentioning: match.id, "repeated"))
        await #expect(throws: AppError.matchNotReady, "another winner is no repeat") {
            try await repository.walkover(id: started.id, matchID: match.id, winnerEntryID: loser)
        }
    }

    @Test func aDisputeIsNeverReplayed() async throws {
        let id = MockTournamentFixtures.tableTennisID
        let theirs = MockTournamentFixtures.tableTennisReport.matchID
        let disputed = try await repository.dispute(id: id, matchID: theirs)
        #expect(disputed.match(id: theirs)?.isOpenDispute == true)

        await #expect(throws: AppError.matchNotReady, "an open match holds no report to answer") {
            try await repository.dispute(id: id, matchID: theirs)
        }
        #expect(!logger.hasLine(in: .tournaments, mentioning: "repeated"))
    }

    /// The mock holds one caller, so the other hand is a fixture member's.
    @Test func aResultStandingByAnotherHandIsNoRepeat() async throws {
        let id = MockTournamentFixtures.tableTennisID
        let detail = try await repository.tournament(id: id)
        let recorded = try #require(callersRoundOneMatch(in: detail))
        let scoreA = try #require(recorded.scoreA)
        let scoreB = try #require(recorded.scoreB)
        await #expect(throws: AppError.matchNotReady, "a side resending the organiser's score") {
            try await repository.report(id: id, matchID: recorded.id, scoreA: scoreA, scoreB: scoreB)
        }

        let league = try await startedLeague()
        let stored = try #require(repository.details[league.id])
        var matches = stored.matches
        matches[0] = matches[0].recording(3, 1, by: MockGroupFixtures.memberID(for: "Marta"), at: .now)
        repository.details[league.id] = stored.replacing(matches: matches, standings: stored.standings)
        await #expect(throws: AppError.matchNotReady, "the organiser resending a player's standing score") {
            try await repository.report(id: league.id, matchID: matches[0].id, scoreA: 3, scoreB: 1)
        }
        #expect(!logger.hasLine(in: .tournaments, mentioning: "repeated"))
    }

    private func startedLeague() async throws -> TournamentDetail {
        repository.seedLeague(id: Self.leagueID)
        return try await repository.start(id: Self.leagueID)
    }

    /// The caller's match of round one, which the fixture's organiser recorded.
    private func callersRoundOneMatch(in detail: TournamentDetail) -> TournamentMatch? {
        guard let mine = detail.myEntry else { return nil }
        return detail.matches.first { $0.round == 1 && $0.contains(entryID: mine.id) }
    }
}
