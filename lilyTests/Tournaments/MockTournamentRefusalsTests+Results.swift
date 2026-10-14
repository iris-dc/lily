import Foundation
import Testing
@testable import lily

extension MockTournamentRefusalsTests {
    // MARK: Results

    @Test func reportRefusesAScoreOutsideTheRange() async throws {
        let id = MockTournamentFixtures.tableTennisID
        let matchID = MockTournamentFixtures.tableTennisScheduledMatchID
        let range = AppConfig.Tournaments.scoreRange
        await #expect(throws: AppError.tournamentActionFailed) {
            try await repository.report(id: id, matchID: matchID, scoreA: range.upperBound + 1, scoreB: 0)
        }
        await #expect(throws: AppError.tournamentActionFailed) {
            try await repository.report(id: id, matchID: matchID, scoreA: range.lowerBound - 1, scoreB: 0)
        }
        let detail = try await repository.tournament(id: id)
        let match = try #require(detail.match(id: matchID))
        #expect(match.status.isOpen && match.scoreA == nil)
    }

    @Test func scheduleRefusesADecidedMatch() async throws {
        let id = "league"
        repository.seedLeague(id: id)
        _ = try await repository.start(id: id)
        let played = try await repository.report(id: id, matchID: "r01p001", scoreA: 2, scoreB: 1)
        #expect(played.match(id: "r01p001")?.isDecided == true)
        await #expect(throws: AppError.matchNotReady) {
            try await repository.schedule(id: id, matchID: "r01p001", MatchSchedule(scheduledAt: now))
        }
    }

    // MARK: Scopes

    @Test func theGroupScopeLeavesCancelledOnesOut() async throws {
        let runners = MockGroupFixtures.ref(for: MockGroupFixtures.runnersID)
        seed(.fixture(id: "live", group: runners))
        seed(.fixture(id: "off", status: .cancelled, group: runners))
        let listed = try await repository.tournaments(in: .group(id: MockGroupFixtures.runnersID), near: nil)
        #expect(listed.map(\.id) == ["live"])
    }

    @Test func upcomingLeavesAPastStartOut() async throws {
        seed(.fixture(id: "past", startsAt: now.addingTimeInterval(-60)))
        seed(.fixture(id: "soon", startsAt: now.addingTimeInterval(60)))
        let ids = try await repository.tournaments(in: .upcoming, near: nil).map(\.id)
        #expect(ids.contains("soon") && !ids.contains("past"))
    }

    // MARK: The guest

    /// The guest is refused before any other check, so even a nonsense winner id answers 401.
    @Test func aGuestIsRefusedOnOrganiserAndMatchRoutes() async throws {
        let (cup, giants) = try await kickersCup()
        let tableTennis = try await repository.tournament(id: MockTournamentFixtures.tableTennisID)
        identity.currentUserID = nil

        for (route, write) in guestWrites(cup: cup, giants: giants, tableTennis: tableTennis) {
            await #expect(throws: AppError.sessionExpired, "\(route)") { try await write() }
        }

        identity.currentUserID = Self.callerID
        let cupAfter = try await repository.tournament(id: cup.id)
        let tableTennisAfter = try await repository.tournament(id: tableTennis.id)
        #expect(cupAfter == cup && tableTennisAfter == tableTennis)
    }

    private func guestWrites(cup: TournamentDetail,
                             giants: TournamentEntry,
                             tableTennis: TournamentDetail) -> [(route: String, write: @MainActor () async throws -> Void)] {
        let repository = self.repository
        let (cupID, tennis) = (cup.id, tableTennis.id)
        let open = MockTournamentFixtures.tableTennisScheduledMatchID
        let reported = MockTournamentFixtures.tableTennisReport.matchID
        return [
            ("update", { _ = try await repository.update(id: cupID, TournamentDraft(editing: cup.tournament)) }),
            ("cancel", { _ = try await repository.cancel(id: cupID) }),
            ("start", { _ = try await repository.start(id: cupID) }),
            ("removeEntry", { try await repository.removeEntry(id: cupID, entryID: giants.id) }),
            ("leave", { _ = try await repository.leave(id: cupID, entryID: giants.id, userID: giants.captainUserId) }),
            ("report", { _ = try await repository.report(id: tennis, matchID: open, scoreA: 3, scoreB: 1) }),
            ("confirm", { _ = try await repository.confirm(id: tennis, matchID: reported) }),
            ("dispute", { _ = try await repository.dispute(id: tennis, matchID: reported) }),
            ("walkover", { _ = try await repository.walkover(id: tennis, matchID: open, winnerEntryID: "any") }),
            ("schedule", { _ = try await repository.schedule(id: tennis, matchID: open, MatchSchedule()) }),
        ]
    }

    // MARK: The epoch

    /// The tournament owns the epoch and the room follows it: one bump per departure, however many players left.
    @Test func aDepartureBumpsTheRoomEpochOnce() async throws {
        let (cup, giants) = try await kickersCup()
        let roomBefore = try await groups.group(id: cup.id)
        #expect(cup.tournament.channelEpoch == 1 && roomBefore.channelEpoch == 1)

        try await repository.removeEntry(id: cup.id, entryID: giants.id)

        let detail = try await repository.tournament(id: cup.id)
        let room = try await groups.group(id: cup.id)
        #expect(detail.tournament.channelEpoch == 2 && room.channelEpoch == 2)
    }

    /// The organiser stays in the room, so their own entry's departure rotates nothing.
    @Test func theOrganisersOwnDepartureMovesNoEpoch() async throws {
        let id = MockTournamentFixtures.kickersCupID
        let solo = try await repository.join(id: id, teamName: "Solo")
        let left = try await repository.leave(id: id, entryID: solo.id, userID: Self.callerID)
        #expect(left == nil)
        let detail = try await repository.tournament(id: id)
        let room = try await groups.group(id: id)
        #expect(detail.tournament.channelEpoch == 1 && room.channelEpoch == 1 && detail.tournament.entryCount == 4)
    }

    // MARK: The format's floor

    /// The backend refuses this with a bare 400 (no code), so each route answers its own fallback.
    @Test func aCapBelowTheFormatsMinimumIsRefusedLikeTheBackend() async throws {
        var draft = TournamentDraft.fixture(now: now)
        draft.format = .roundRobin
        draft.maxEntries = 2
        await #expect(throws: AppError.tournamentCreationFailed) { try await repository.create(draft) }
        draft.maxEntries = 3
        let created = try await repository.create(draft)
        #expect(created.tournament.maxEntries == 3)

        seed(.fixture(id: "league",
                      maxEntries: 4,
                      entryCount: 0,
                      startsAt: tomorrow,
                      organizerUserId: MockTournamentFixtures.callerMarker))
        let league = try await repository.tournament(id: "league")
        var edit = TournamentDraft(editing: league.tournament)
        edit.maxEntries = 2
        await #expect(throws: AppError.tournamentUpdateFailed) { try await repository.update(id: "league", edit) }
        edit.maxEntries = 3
        let updated = try await repository.update(id: "league", edit)
        #expect(updated.tournament.maxEntries == 3)
    }

    @Test func theFormatsFloorIsJudgedBeforeTheEntriesAlreadyIn() async throws {
        let (cup, _) = try await kickersCup()
        var draft = TournamentDraft(editing: cup.tournament)
        draft.maxEntries = 2
        await #expect(throws: AppError.capacityTooLow) { try await repository.update(id: cup.id, draft) }
        draft.format = .roundRobin
        await #expect(throws: AppError.tournamentUpdateFailed) { try await repository.update(id: cup.id, draft) }
    }
}
