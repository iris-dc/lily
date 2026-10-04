import Foundation
import Testing
@testable import lily

/// The mock's refusals and transitions where the backend's rules are finer than `MockTournamentRepositoryTests` pins:
/// who may answer a report and what a dispute leaves, a match id that names nothing, a round robin's completion, and an
/// edit after the start. Same fixtures and identity as that suite.
@MainActor
struct MockTournamentRepositoryRulesTests {
    private static let leagueID = "mock-tournament-league"
    private let identity = FakeIdentityProvider(currentUserID: "mock-apple")
    private let logger = SpyLogger()
    private let repository: MockTournamentRepository

    init() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let groups = MockGroupRepository(identity: identity, logger: logger, now: { now })
        repository = MockTournamentRepository(groups: groups, identity: identity, logger: logger, now: { now })
    }

    /// A three-player round robin the caller organises without playing, draws allowed, ready to start.
    private func seedLeague() {
        let players = ["Marta", "Jonas", "Dev"].enumerated().map { index, name in
            TournamentEntry.fixture(id: "league-e\(index + 1)",
                                    tournamentId: Self.leagueID,
                                    name: name,
                                    captainUserId: MockGroupFixtures.memberID(for: name),
                                    seed: index + 1)
        }
        let league = Tournament.fixture(id: Self.leagueID,
                                        name: "Thursday League",
                                        format: .roundRobin,
                                        entryCount: players.count,
                                        allowsDraws: true,
                                        organizerUserId: MockTournamentFixtures.callerMarker)
        repository.details[Self.leagueID] = .fixture(tournament: league, entries: players)
    }

    /// The caller plays Tuesday Table Tennis: their report waits for the other side, who alone (or the organiser) may
    /// confirm or dispute it; disputing Jonas's report drops it and reopens the match with the flag.
    @Test func aPlayersReportWaitsForTheOtherSideWhoAloneAnswersIt() async throws {
        let id = MockTournamentFixtures.tableTennisID
        let detail = try await repository.tournament(id: id)
        let mine = try #require(detail.myEntry)
        let pending = try #require(detail.matches.first { $0.contains(entryID: mine.id) && $0.status == .pending })

        let reported = try await repository.report(id: id, matchID: pending.id, scoreA: 3, scoreB: 2)
        #expect(reported.match(id: pending.id)?.status == .reported)
        await #expect(throws: AppError.matchNotReady) { try await repository.confirm(id: id, matchID: pending.id) }
        await #expect(throws: AppError.matchNotReady, "the reporting side reports again; it answers nothing") {
            try await repository.dispute(id: id, matchID: pending.id)
        }

        let theirs = MockTournamentFixtures.tableTennisReport.matchID
        let disputed = try await repository.dispute(id: id, matchID: theirs)
        let reopened = try #require(disputed.match(id: theirs))
        #expect(reopened.isDisputed && reopened.isOpenDispute && reopened.status == .pending)
        #expect(reopened.scoreA == nil && reopened.reportedBy == nil, "the report is dropped, as the backend drops it")
        let fresh = try await repository.report(id: id, matchID: theirs, scoreA: 2, scoreB: 3)
        #expect(fresh.match(id: theirs)?.status == .reported && fresh.match(id: theirs)?.isDisputed == true,
                "a fresh report after a dispute keeps the flag")

        let other = try #require(detail.matches.first { !$0.contains(entryID: mine.id) && !$0.isDecided })
        await #expect(throws: AppError.notInMatch) {
            try await repository.report(id: id, matchID: other.id, scoreA: 3, scoreB: 0)
        }
    }

    @Test func aRoundRobinCompletesOnItsLastResultWithTheTablesLeader() async throws {
        seedLeague()
        let id = Self.leagueID
        let started = try await repository.start(id: id)
        #expect(started.matches.count == 3 && started.standings.count == 3 && started.standings.allSatisfy { $0.played == 0 })

        let first = try await repository.report(id: id, matchID: "r01p001", scoreA: 3, scoreB: 0)
        let recorded = try #require(first.match(id: "r01p001"))
        #expect(first.tournament.status == .inProgress && recorded.status == .confirmed)
        #expect(recorded.reportedBy == "mock-apple" && recorded.confirmedBy == "mock-apple",
                "the organiser's record stamps them as reporter and confirmer alike")
        _ = try await repository.report(id: id, matchID: "r02p001", scoreA: 1, scoreB: 3)
        let completed = try await repository.report(id: id, matchID: "r03p001", scoreA: 2, scoreB: 2)
        let leader = try #require(completed.standings.first)
        #expect(completed.tournament.status == .completed && completed.tournament.completedAt != nil)
        #expect(completed.tournament.winnerEntryId == leader.entryId && leader.points > completed.standings[2].points)
        await #expect(throws: AppError.matchNotReady, "nothing moves once it is over") {
            try await repository.report(id: id, matchID: "r01p001", scoreA: 1, scoreB: 0)
        }
    }

    @Test func aMatchIdThatNamesNothingIsNotFound() async throws {
        seedLeague()
        let id = Self.leagueID
        await #expect(throws: AppError.matchNotReady, "no match route before the start") {
            try await repository.report(id: id, matchID: "r01p001", scoreA: 1, scoreB: 0)
        }
        _ = try await repository.start(id: id)
        await #expect(throws: AppError.matchNotFound) {
            try await repository.report(id: id, matchID: "r09p009", scoreA: 1, scoreB: 0)
        }
        await #expect(throws: AppError.matchNotFound) {
            try await repository.schedule(id: id, matchID: "r09p009", MatchSchedule())
        }
    }

    @Test func aStartedTournamentStillTakesARenameButNotANewCap() async throws {
        seedLeague()
        let id = Self.leagueID
        let started = try await repository.start(id: id)
        var draft = TournamentDraft(editing: started.tournament)
        draft.name = "Thursday Cup"
        let renamed = try await repository.update(id: id, draft)
        #expect(renamed.tournament.name == "Thursday Cup" && renamed.tournament.status == .inProgress)
        draft.maxEntries += 1
        await #expect(throws: AppError.tournamentLocked) { try await repository.update(id: id, draft) }
    }

    /// The organiser answers a side's report like the other side would: a confirmation keeps the reporter, a dispute
    /// reopens the match.
    @Test func theOrganiserConfirmsOrDisputesASidesReport() async throws {
        let id = Self.leagueID
        seedLeague()
        _ = try await repository.start(id: id)
        // The stored rows, not the answer: the answer has the caller's id swapped in for the marker.
        let stored = try #require(repository.details[id])
        var matches = stored.matches
        let sideA = try #require(stored.entry(id: matches[0].entryAId ?? ""))
        let sideB = try #require(stored.entry(id: matches[1].entryBId ?? ""))
        matches[0] = matches[0].reporting(3, 1, by: sideA.captainUserId, at: .now)
        matches[1] = matches[1].reporting(0, 3, by: sideB.captainUserId, at: .now)
        repository.details[id] = stored.replacing(matches: matches, standings: stored.standings)

        let confirmed = try await repository.confirm(id: id, matchID: matches[0].id)
        let settled = try #require(confirmed.match(id: matches[0].id))
        #expect(settled.status == .confirmed && settled.confirmedBy == "mock-apple" && settled.reportedBy != "mock-apple")
        let disputed = try await repository.dispute(id: id, matchID: matches[1].id)
        #expect(disputed.match(id: matches[1].id)?.isOpenDispute == true)
    }

    /// Who may act is judged before the registration window, and the tournament's status before the organiser's seat.
    @Test func refusalsComeInTheBackendsOrder() async throws {
        let tableTennis = MockTournamentFixtures.tableTennisID
        let detail = try await repository.tournament(id: tableTennis)
        let jonas = try #require(detail.entries.first { $0.name == "Jonas" })
        await #expect(throws: AppError.insufficientRole, "a stranger is refused before the closed window") {
            try await repository.leave(id: tableTennis, entryID: jonas.id, userID: jonas.captainUserId)
        }
        let open = try #require(detail.matches.first { $0.isReadyForResult })
        await #expect(throws: AppError.notOrganizer) {
            try await repository.walkover(id: tableTennis, matchID: open.id, winnerEntryID: open.entryAId ?? "")
        }
        seedLeague()
        await #expect(throws: AppError.matchNotReady, "the status is judged before the organiser's seat") {
            try await repository.walkover(id: Self.leagueID, matchID: "r01p001", winnerEntryID: "league-e1")
        }

        let teams = MockTournamentFixtures.kickersCupID
        let cup = try await repository.tournament(id: teams)
        repository.details[teams] = cup.replacing(tournament: cup.tournament.starting(at: .now))
        let full = try #require(cup.entries.first { $0.isFull(teamSize: cup.tournament.teamSize) })
        let open2 = try #require(cup.entries.first { !$0.isFull(teamSize: cup.tournament.teamSize) })
        await #expect(throws: AppError.teamFull, "the team's refusal before the root's") {
            try await repository.joinTeam(id: teams, entryID: full.id)
        }
        await #expect(throws: AppError.registrationClosed) { try await repository.joinTeam(id: teams, entryID: open2.id) }
    }

    /// Mine lists the finished ones by their last change: the completion, else the last edit, else the creation.
    @Test func mineOrdersTheFinishedOnesByTheirLastChange() async throws {
        let marker = MockTournamentFixtures.callerMarker
        let earlier = Date(timeIntervalSince1970: 1_799_000_000)
        let later = earlier.addingTimeInterval(3600)
        let completed = Tournament.fixture(id: "done", name: "Done", organizerUserId: marker)
            .completing(winnerEntryId: "e", at: earlier)
        let cancelled = Tournament.fixture(id: "off", name: "Off", organizerUserId: marker).cancelling(at: later)
        repository.details["done"] = .fixture(tournament: completed)
        repository.details["off"] = .fixture(tournament: cancelled)

        let mine = try await repository.tournaments(in: .mine, near: nil)
        #expect(mine.map(\.id).suffix(2) == ["off", "done"], "the most recently changed first, after the open ones")
    }
}
