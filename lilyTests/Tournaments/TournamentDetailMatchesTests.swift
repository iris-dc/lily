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

    @Test func aTryAgainOnTheStartIsRepeatedOnce() async {
        let viewModel = await loaded(cup, entries: teams)
        harness.repository.transientErrors = [.tryAgain]

        await viewModel.start()

        #expect(harness.repository.startedIDs == ["t", "t"] && viewModel.hasMatches)
    }
}
