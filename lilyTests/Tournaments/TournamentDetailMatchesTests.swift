import Foundation
import Testing
@testable import lily

/// The start and the results from the detail: every write's answer replaces the detail and reaches the lists behind;
/// Start is the organiser's while registration is open; the rules a cell and the sheet follow come from the loaded detail.
@MainActor
struct TournamentDetailMatchesTests {
    private let harness = TournamentHarness()
    private let destination = TournamentDestination(id: "t", name: "Kickers Cup")
    private let teams = (1...4).map { seed in
        TournamentEntry.fixture(id: "e\(seed)", name: "Team \(seed)", captainUserId: Self.captain(seed), seed: seed)
    }

    /// The test user captains the first entry; the rest are fixture users.
    private static func captain(_ seed: Int) -> String {
        seed == 1 ? TestFixtures.user.id : "u-\(seed)"
    }

    private func loaded(_ tournament: Tournament, entries: [TournamentEntry]) async -> TournamentDetailViewModel {
        harness.repository.details["t"] = .fixture(tournament: tournament, entries: entries)
        let viewModel = harness.makeDetailViewModel(for: destination)
        await viewModel.load()
        return viewModel
    }

    private var cup: Tournament {
        .fixture(id: "t",
                 name: "Kickers Cup",
                 type: .football,
                 format: .singleElimination,
                 teamSize: 5,
                 entryCount: 4,
                 organizerUserId: TestFixtures.user.id,
                 myEntryId: "e1")
    }

    @Test func startIsTheOrganisersWhileRegistrationIsOpenAndNeedsTheMinimum() async {
        let one = Tournament.fixture(id: "t",
                                     format: .singleElimination,
                                     teamSize: 5,
                                     entryCount: 1,
                                     organizerUserId: TestFixtures.user.id)
        let few = await loaded(one, entries: [teams[0]])
        #expect(few.showsStart && !few.canStart && few.startBlockedReason == "Needs at least 2 teams")
        let soloFew = await loaded(.fixture(id: "t", format: .roundRobin, entryCount: 2, organizerUserId: TestFixtures.user.id),
                                   entries: Array(teams.prefix(2)))
        #expect(soloFew.startBlockedReason == "Needs at least 3 players")

        let ready = await loaded(cup, entries: teams)
        #expect(ready.showsStart && ready.canStart && ready.startBlockedReason == nil && !ready.hasMatches)
        let player = await loaded(.fixture(id: "t", entryCount: 4, myEntryId: "e1"), entries: teams)
        #expect(!player.showsStart && player.startBlockedReason == nil)
    }

    @Test func startDrawsTheMatchesShowsThemAndHandsTheTournamentOn() async {
        let viewModel = await loaded(cup, entries: teams)

        await viewModel.start()

        #expect(viewModel.tournament?.status == .inProgress && viewModel.hasMatches && !viewModel.showsStart)
        #expect(viewModel.detail?.matches.count == 3 && harness.repository.startedIDs == ["t"])
        #expect(harness.sink.tournaments.last?.status == .inProgress)
        #expect(harness.logs(.info).contains { $0.contains("started with 3 matches") })
        #expect(viewModel.entryName("e1") == "Team 1" && viewModel.entryName(nil) == "TBD" && viewModel.entryName("zz") == "TBD")
    }

    @Test func theOrganisersRecordIsFinalAndTheFinalCompletesTheTournament() async throws {
        let viewModel = await loaded(cup, entries: teams)
        await viewModel.start()
        let semi = try #require(viewModel.detail?.match(id: "r01p001"))
        #expect(viewModel.actions(for: semi).canRecord && viewModel.isMine(semi), "the organiser captains Team 1")

        #expect(await viewModel.report(semi, scoreA: 2, scoreB: 1))
        #expect(viewModel.detail?.match(id: "r01p001")?.status == .confirmed)
        #expect(viewModel.detail?.match(id: "r02p001")?.entryAId == "e1", "the winner advances")
        #expect(harness.repository.reports == [FakeTournamentRepository.Report(matchID: "r01p001", scoreA: 2, scoreB: 1)])
        #expect(harness.logs(.info).contains { $0.contains("Match r01p001 of tournament t: result confirmed") })

        let other = try #require(viewModel.detail?.match(id: "r01p002"))
        #expect(await viewModel.walkover(other, winnerEntryID: "e2"))
        #expect(viewModel.detail?.match(id: "r01p002")?.status == .walkover)
        #expect(harness.repository.walkovers.first?.winnerEntryID == "e2")

        let final = try #require(viewModel.detail?.match(id: "r02p001"))
        #expect(await viewModel.report(final, scoreA: 3, scoreB: 0))
        #expect(viewModel.tournament?.status == .completed && viewModel.tournament?.winnerEntryId == "e1")
        #expect(viewModel.winnerName == "Team 1", "the winner line names the entry")
        #expect(harness.logs(.info).contains { $0 == "Tournament t completed" })
        #expect(harness.sink.tournaments.count == 4, "the start and every result reached the lists")
    }

    @Test func aSideReportsThenTheOtherSideConfirmsOrDisputes() async throws {
        let players = (1...3).map { seed in
            TournamentEntry.fixture(id: "p\(seed)", name: "P\(seed)", captainUserId: Self.captain(seed), seed: seed)
        }
        let league = Tournament.fixture(id: "t",
                                        format: .roundRobin,
                                        entryCount: 3,
                                        organizerUserId: "seed-marta",
                                        myEntryId: "p1")
        let viewModel = await loaded(league, entries: players)
        harness.repository.details["t"] = try await harness.repository.start(id: "t")
        await viewModel.load()
        let mine = try #require(viewModel.detail?.matches.first { $0.contains(entryID: "p1") })
        #expect(viewModel.isMine(mine) && viewModel.actions(for: mine).canReport)

        #expect(await viewModel.report(mine, scoreA: 3, scoreB: 1))
        let reported = try #require(viewModel.detail?.match(id: mine.id))
        #expect(reported.status == .reported && viewModel.actions(for: reported).awaitsOtherSide)
        #expect(harness.logs(.info).contains { $0.contains("result reported") })

        // The other side's view of the same match: confirm and dispute go to the repository and come back as the detail.
        #expect(await viewModel.dispute(reported))
        #expect(viewModel.detail?.match(id: mine.id)?.isDisputed == true && harness.repository.disputedMatchIDs == [mine.id])
        let reportedAgain = await viewModel.report(mine, scoreA: 3, scoreB: 1)
        let confirmed = await viewModel.confirm(mine)
        #expect(reportedAgain && confirmed)
        #expect(viewModel.detail?.match(id: mine.id)?.status == .confirmed && harness.repository.confirmedMatchIDs == [mine.id])
    }

    @Test func aRefusalKeepsTheDetailReportsItAndAnswersFalse() async throws {
        let viewModel = await loaded(cup, entries: teams)
        await viewModel.start()
        harness.repository.actionError = AppError.matchNotReady
        let semi = try #require(viewModel.detail?.match(id: "r01p001"))

        #expect(await viewModel.report(semi, scoreA: 1, scoreB: 0) == false)

        #expect(viewModel.detail?.match(id: "r01p001")?.status == .pending && harness.presentedError == .matchNotReady)
        #expect(harness.logs(.error).contains { $0.contains("Report result failed") })
        harness.identity.currentUserID = nil
        #expect(await viewModel.confirm(semi) == false, "a guest never writes")
    }

    /// The organiser's schedule: the route's match takes its place in the detail, the lists behind learn of it, and a
    /// side may not schedule.
    @Test func theOrganiserSchedulesAMatchAndTheMatchShowsTheTime() async throws {
        let viewModel = await loaded(cup, entries: teams)
        await viewModel.start()
        let semi = try #require(viewModel.detail?.match(id: "r01p001"))
        let when = TournamentHarness.now.addingTimeInterval(86_400)
        let place = EventLocation(name: "Pitch 2", coordinate: AppConfig.Location.mockCenter)
        #expect(viewModel.actions(for: semi).canSchedule)

        #expect(await viewModel.schedule(semi, MatchSchedule(scheduledAt: when, location: place)))

        let scheduled = try #require(viewModel.detail?.match(id: "r01p001"))
        #expect(scheduled.status == .scheduled && scheduled.scheduledAt == when && scheduled.location == place)
        #expect(viewModel.detail?.matches.count == 3 && viewModel.detail?.match(id: "r02p001")?.status == .pending)
        #expect(harness.repository.schedules.map(\.matchID) == ["r01p001"] && harness.sink.tournaments.count == 2)
        #expect(harness.logs(.info).contains("Match r01p001 of tournament t: scheduled"))

        #expect(await viewModel.schedule(scheduled, MatchSchedule()))
        let cleared = viewModel.detail?.match(id: "r01p001")
        #expect(cleared?.scheduledAt == nil && cleared?.location == nil && cleared?.status == .pending)
        #expect(harness.logs(.info).contains("Match r01p001 of tournament t: schedule cleared"))

        let player = await loaded(.fixture(id: "t", status: .inProgress, entryCount: 4, myEntryId: "e1"), entries: teams)
        #expect(!player.actions(for: semi).canSchedule)
    }

    /// Where the schedule form opens: the match's own time and place, else the start (or the next full hour of the
    /// calendar's zone once the start has passed: the harness clock is 08:25:07 UTC) at the tournament's venue.
    @Test func theScheduleProposalStartsFromTheMatchTheStartOrTheNextHour() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let now = TournamentHarness.now
        let nextHour = now.addingTimeInterval(34 * 60 + 53)
        let semi = TournamentMatch(id: "r01p001", tournamentId: "t", round: 1, position: 1, entryAId: "e1", entryBId: "e2")
        let started = Tournament.fixture(id: "t", status: .inProgress, startsAt: now.addingTimeInterval(-3_600))
        let upcoming = Tournament.fixture(id: "t", status: .inProgress, startsAt: now.addingTimeInterval(86_400))
        let place = EventLocation(name: "Pitch 2", coordinate: AppConfig.Location.mockCenter)
        let timed = semi.scheduling(MatchSchedule(scheduledAt: now.addingTimeInterval(7_200), location: place))

        let fromStart = MatchSchedule.proposal(for: semi, in: started, now: now, calendar: utc)
        #expect(fromStart == MatchSchedule(scheduledAt: nextHour, location: started.location))
        #expect(MatchSchedule.proposal(for: semi, in: upcoming, now: now, calendar: utc).scheduledAt == upcoming.startsAt)
        let kept = MatchSchedule.proposal(for: timed, in: started, now: now, calendar: utc)
        #expect(kept == MatchSchedule(scheduledAt: timed.scheduledAt, location: place))
        var halfHour = utc
        halfHour.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let inKolkata = MatchSchedule.proposal(for: semi, in: started, now: now, calendar: halfHour)
        #expect(inKolkata.scheduledAt == now.addingTimeInterval(4 * 60 + 53), "the next full hour of a half-hour zone")
    }

    @Test func aTryAgainOnTheStartIsRepeatedOnce() async {
        let viewModel = await loaded(cup, entries: teams)
        harness.repository.transientErrors = [.tryAgain]

        await viewModel.start()

        #expect(harness.repository.startedIDs == ["t", "t"] && viewModel.hasMatches)
    }
}
