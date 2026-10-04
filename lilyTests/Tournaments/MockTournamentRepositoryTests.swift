import Foundation
import Testing
@testable import lily

/// The mock behaves like the backend for the fixtures and the writes: the caller is whoever `identity` names, the
/// rooms live in the group mock, and the draw and the results follow the backend's rules.
@MainActor
struct MockTournamentRepositoryTests {
    private let identity = FakeIdentityProvider(currentUserID: "mock-apple")
    private let logger = SpyLogger()
    private let groups: MockGroupRepository
    private let repository: MockTournamentRepository
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    init() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        groups = MockGroupRepository(identity: identity, logger: logger, now: { now })
        repository = MockTournamentRepository(groups: groups, identity: identity, logger: logger, now: { now })
    }

    @Test func theFixturesAreAsThePlanDescribes() async throws {
        let cup = try await repository.tournament(id: MockTournamentFixtures.kickersCupID).tournament
        #expect(cup.name == "Kickers Cup" && cup.teamSize == 5 && cup.format == .singleElimination)
        #expect(cup.status == .registration && cup.entryCount == 4 && cup.group?.id == MockGroupFixtures.kickersID)
        #expect(cup.organizerUserId == "mock-apple" && cup.myEntryId == nil, "the caller organises, not entered")
        let cupDetail = try await repository.tournament(id: MockTournamentFixtures.kickersCupID)
        #expect(cupDetail.entries.count == 4 && cupDetail.matches.isEmpty)

        let tableTennis = try await repository.tournament(id: MockTournamentFixtures.tableTennisID)
        let table = tableTennis.tournament
        #expect(table.status == .inProgress && table.format == .roundRobin && table.teamSize == 1)
        #expect(table.organizerName == "Marta")
        #expect(tableTennis.entries.count == 6 && tableTennis.matches.count == 15)
        #expect(tableTennis.matches.filter(\.isDecided).count == 3 && tableTennis.standings.count == 6)
        let mine = try #require(tableTennis.myEntry)
        #expect(mine.seed == MockTournamentFixtures.callerTableTennisSeed && mine.contains(userID: "mock-apple"))
        #expect(tableTennis.standings.first?.points == 3, "a winner leads the table")
        let reported = try #require(tableTennis.match(id: MockTournamentFixtures.tableTennisReport.matchID))
        #expect(reported.status == .reported && reported.contains(entryID: mine.id) && reported.reportedBy == "mock-user-jonas")
        let disputed = try #require(tableTennis.match(id: MockTournamentFixtures.tableTennisDispute.matchID))
        #expect(disputed.isDisputed && disputed.status == .pending && disputed.scoreA == 3, "the scores stay for the organiser")
    }

    @Test func listsFollowTheirScopes() async throws {
        let upcoming = try await repository.tournaments(in: .upcoming, near: nil)
        #expect(upcoming.map(\.id) == [MockTournamentFixtures.kickersCupID], "the started one is off Explore")
        let mine = try await repository.tournaments(in: .mine, near: nil)
        #expect(mine.map(\.id) == [MockTournamentFixtures.tableTennisID, MockTournamentFixtures.kickersCupID],
                "in progress first")
        let group = try await repository.tournaments(in: .group(id: MockGroupFixtures.kickersID), near: nil)
        #expect(group.map(\.id) == [MockTournamentFixtures.kickersCupID])

        identity.currentUserID = nil
        #expect(try await repository.tournaments(in: .mine, near: nil).isEmpty)
        let guestView = try await repository.tournaments(in: .upcoming, near: nil)
        #expect(guestView.first?.organizerUserId == MockTournamentFixtures.callerMarker, "a guest sees no organiser of their own")
    }

    /// The rooms are in the group mock: Chats lists them, Home (communities) does not.
    @Test func theRoomsAreGroupsOfKindTournament() async throws {
        let mine = try await groups.groups(in: .mine, cursor: nil).items
        let cup = try #require(mine.first { $0.id == MockTournamentFixtures.kickersCupID })
        #expect(cup.isTournamentRoom && cup.role == .owner && cup.maxMembers == 41 && !cup.isCommunity)
        let tableTennis = try #require(mine.first { $0.id == MockTournamentFixtures.tableTennisID })
        #expect(tableTennis.role == .member && tableTennis.memberCount == 6 && tableTennis.caption().hasPrefix("Tournament"))
        #expect(mine.filter(\.isCommunity).count == AppConfig.Groups.mockGroupCount - 3, "three fixture communities are theirs")
        let roster = try await groups.members(id: MockTournamentFixtures.tableTennisID)
        #expect(roster.count == 6 && roster.contains { $0.displayName == "Marta" })
    }

    @Test func creatingATeamJoinsTheRoomAndLeavingEmptiesIt() async throws {
        let id = MockTournamentFixtures.kickersCupID
        let entry = try await repository.join(id: id, teamName: "Late Bloomers")
        #expect(entry.name == "Late Bloomers" && entry.captainUserId == "mock-apple" && entry.seed == 5)
        var detail = try await repository.tournament(id: id)
        #expect(detail.tournament.entryCount == 5 && detail.tournament.myEntryId == entry.id)
        #expect(try await groups.group(id: id).role == .owner, "the organiser keeps the owner row")

        await #expect(throws: AppError.alreadyEntered) { try await repository.join(id: id, teamName: "Twice") }

        let left = try await repository.leave(id: id, entryID: entry.id, userID: "mock-apple")
        #expect(left == nil, "an emptied entry is gone")
        detail = try await repository.tournament(id: id)
        #expect(detail.tournament.entryCount == 4 && detail.tournament.myEntryId == nil)
    }

    @Test func joiningATeamAndRefusals() async throws {
        let id = MockTournamentFixtures.kickersCupID
        let detail = try await repository.tournament(id: id)
        let giants = try #require(detail.entries.first { $0.name == "Görli Giants" })
        await #expect(throws: AppError.teamFull) { try await repository.joinTeam(id: id, entryID: giants.id) }
        await #expect(throws: AppError.entryNotFound) { try await repository.joinTeam(id: id, entryID: "nope") }
        let united = try #require(detail.entries.first { $0.name == "Hasenheide United" })
        let joined = try await repository.joinTeam(id: id, entryID: united.id)
        #expect(joined.memberCount == 2 && joined.contains(userID: "mock-apple"))
        await #expect(throws: AppError.alreadyEntered) { try await repository.joinTeam(id: id, entryID: united.id) }
        await #expect(throws: AppError.registrationClosed) {
            try await repository.join(id: MockTournamentFixtures.tableTennisID, teamName: nil)
        }
        await #expect(throws: AppError.tournamentNotFound) { try await repository.tournament(id: "missing") }
    }

    @Test func createReplaysAndUpdateFollowsTheLockRules() async throws {
        var draft = TournamentDraft.fixture(now: now)
        draft.format = .roundRobin
        let created = try await repository.create(draft)
        #expect(created.tournament.organizerUserId == "mock-apple" && created.tournament.entryCount == 0)
        let replayed = try await repository.create(draft)
        #expect(replayed == created, "a replay answers the same tournament")
        #expect(groups.find(draft.clientId)?.isTournamentRoom == true)

        draft.name = "Renamed Cup"
        let updated = try await repository.update(id: draft.clientId, draft)
        #expect(updated.tournament.name == "Renamed Cup" && groups.find(draft.clientId)?.name == "Renamed Cup")

        await #expect(throws: AppError.notOrganizer) {
            try await repository.update(id: MockTournamentFixtures.tableTennisID, .fixture(now: now))
        }
        await #expect(throws: AppError.notOrganizer) { try await repository.cancel(id: MockTournamentFixtures.tableTennisID) }
        let cancelled = try await repository.cancel(id: draft.clientId)
        #expect(cancelled.tournament.status == .cancelled)
    }

    @Test func startDrawsTheMatchesAndResultsAdvance() async throws {
        let id = MockTournamentFixtures.kickersCupID
        let started = try await repository.start(id: id)
        #expect(started.tournament.status == .inProgress && started.matches.count == 3, "four teams: two semi-finals and a final")
        #expect(try await repository.start(id: id).matches.count == 3, "a second start replays")

        let semi = try #require(started.matches.first { $0.id == "r01p001" })
        let recorded = try await repository.report(id: id, matchID: semi.id, scoreA: 2, scoreB: 1)
        let final = try #require(recorded.match(id: "r02p001"))
        #expect(recorded.match(id: semi.id)?.status == .confirmed, "the organiser's result is confirmed at once")
        #expect(final.entryAId == semi.entryAId, "the winner advances")
        await #expect(throws: AppError.drawNotAllowed) {
            try await repository.report(id: id, matchID: "r01p002", scoreA: 1, scoreB: 1)
        }
        await #expect(throws: AppError.matchNotReady) {
            try await repository.report(id: id, matchID: semi.id, scoreA: 2, scoreB: 1)
        }
    }

    @Test func aPlayersReportWaitsForTheOtherSide() async throws {
        let id = MockTournamentFixtures.tableTennisID
        let detail = try await repository.tournament(id: id)
        let mine = try #require(detail.myEntry)
        let pending = try #require(detail.matches.first { $0.contains(entryID: mine.id) && $0.status == .pending })

        let reported = try await repository.report(id: id, matchID: pending.id, scoreA: 3, scoreB: 2)
        #expect(reported.match(id: pending.id)?.status == .reported)
        await #expect(throws: AppError.matchNotReady) { try await repository.confirm(id: id, matchID: pending.id) }
        let disputed = try await repository.dispute(id: id, matchID: pending.id)
        #expect(disputed.match(id: pending.id)?.isDisputed == true && disputed.match(id: pending.id)?.status == .pending)

        let other = try #require(detail.matches.first { !$0.contains(entryID: mine.id) && !$0.isDecided })
        await #expect(throws: AppError.notInMatch) {
            try await repository.report(id: id, matchID: other.id, scoreA: 3, scoreB: 0)
        }
    }

    /// Jonas reported 3–2 against the caller: confirming it, or reporting the same score, makes it final and moves him
    /// to the top of the table; a different score is a report of the caller's own, waiting for Jonas.
    @Test func theOtherSidesReportIsConfirmedByAgreeingWithIt() async throws {
        let id = MockTournamentFixtures.tableTennisID
        let matchID = MockTournamentFixtures.tableTennisReport.matchID

        let confirmed = try await repository.confirm(id: id, matchID: matchID)
        #expect(confirmed.match(id: matchID)?.status == .confirmed && confirmed.match(id: matchID)?.confirmedBy == "mock-apple")
        let leader = try #require(confirmed.standings.first)
        #expect(leader.points == 6 && confirmed.entry(id: leader.entryId)?.name == "Jonas")

        let second = MockTournamentRepository(groups: groups, identity: identity, logger: logger, now: { now })
        let agreed = try await second.report(id: id, matchID: matchID, scoreA: 3, scoreB: 2)
        #expect(agreed.match(id: matchID)?.status == .confirmed, "the same score from the other side confirms")

        let third = MockTournamentRepository(groups: groups, identity: identity, logger: logger, now: { now })
        let disagreed = try await third.report(id: id, matchID: matchID, scoreA: 2, scoreB: 3)
        #expect(disagreed.match(id: matchID)?.status == .reported && disagreed.match(id: matchID)?.reportedBy == "mock-apple")
    }

    /// The organiser's walkover advances like a result, and the final's result completes the bracket.
    @Test func aWalkoverAdvancesAndTheFinalCompletesTheTournament() async throws {
        let id = MockTournamentFixtures.kickersCupID
        let started = try await repository.start(id: id)
        let semi = try #require(started.match(id: "r01p001"))
        let winner = try #require(semi.entryBId)

        let afterWalkover = try await repository.walkover(id: id, matchID: semi.id, winnerEntryID: winner)
        #expect(afterWalkover.match(id: semi.id)?.status == .walkover && afterWalkover.match(id: "r02p001")?.entryAId == winner)
        await #expect(throws: AppError.tournamentActionFailed) {
            try await repository.walkover(id: id, matchID: "r01p002", winnerEntryID: "nobody")
        }

        let afterSecond = try await repository.report(id: id, matchID: "r01p002", scoreA: 0, scoreB: 2)
        let final = try #require(afterSecond.match(id: "r02p001"))
        #expect(final.hasBothSides && final.entryBId == afterSecond.match(id: "r01p002")?.entryBId)
        let completed = try await repository.report(id: id, matchID: final.id, scoreA: 1, scoreB: 0)
        #expect(completed.tournament.status == .completed && completed.tournament.winnerEntryId == winner)
        await #expect(throws: AppError.matchNotReady) {
            try await repository.report(id: id, matchID: final.id, scoreA: 1, scoreB: 0)
        }
    }
}
