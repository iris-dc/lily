import Foundation
import Testing
@testable import lily

/// A match write whose answer was lost is read back before it is reported. The fake stores the write and then throws
/// the scripted error, as a commit whose answer never arrived.
@MainActor
struct TournamentDetailLostAnswerTests {
    private let harness = TournamentHarness()
    private let destination = TournamentDestination(id: "t", name: "Kickers Cup")

    /// The test user captains the first entry; the rest are fixture users.
    private static func captain(_ seed: Int) -> String {
        seed == 1 ? TestFixtures.user.id : "u-\(seed)"
    }

    /// A started round robin of three players the caller plays in as `p1` and Marta organises, with the caller's first
    /// match: a side's writes.
    private func startedLeague() async throws -> (viewModel: TournamentDetailViewModel, mine: TournamentMatch) {
        let players = (1...3).map { seed in
            TournamentEntry.fixture(id: "p\(seed)", name: "P\(seed)", captainUserId: Self.captain(seed), seed: seed)
        }
        let league = Tournament.fixture(id: "t",
                                        format: .roundRobin,
                                        entryCount: 3,
                                        organizerUserId: "seed-marta",
                                        myEntryId: "p1")
        let viewModel = await harness.loadedDetailViewModel(league, entries: players, for: destination)
        harness.repository.details["t"] = try await harness.repository.start(id: "t")
        await viewModel.load()
        let mine = try #require(viewModel.detail?.matches.first { $0.contains(entryID: "p1") })
        return (viewModel, mine)
    }

    /// A started cup of four teams the caller organises and captains Team 1 in: the organiser's writes.
    private func startedCup() async -> TournamentDetailViewModel {
        let teams = (1...4).map { seed in
            TournamentEntry.fixture(id: "e\(seed)", name: "Team \(seed)", captainUserId: Self.captain(seed), seed: seed)
        }
        let cup = Tournament.fixture(id: "t",
                                     format: .singleElimination,
                                     teamSize: 5,
                                     entryCount: 4,
                                     organizerUserId: TestFixtures.user.id,
                                     myEntryId: "e1")
        let viewModel = await harness.loadedDetailViewModel(cup, entries: teams, for: destination)
        await viewModel.start()
        return viewModel
    }

    /// The other side's 3–1 report on the caller's match, stored as the backend holds it and loaded onto the screen.
    private func reportedByTheOtherSide(_ viewModel: TournamentDetailViewModel,
                                        _ match: TournamentMatch) async throws -> TournamentMatch {
        let stored = try #require(harness.repository.details["t"])
        let otherSide = try #require([match.entryAId, match.entryBId].compactMap { $0 }.first { $0 != "p1" })
        let captain = try #require(stored.entry(id: otherSide)?.captainUserId)
        harness.repository.details["t"] = stored.replacing(match: match.reporting(3, 1, by: captain, at: .now))
        await viewModel.load()
        return try #require(viewModel.detail?.match(id: match.id))
    }

    @Test func aLostAnswerToAReportThatLandedIsNotReported() async throws {
        let (viewModel, mine) = try await startedLeague()
        let fetches = harness.repository.fetchedIDs.count
        let handedOn = harness.sink.tournaments.count
        harness.repository.lostAnswerError = AppError.network

        #expect(await viewModel.report(mine, scoreA: 3, scoreB: 1))

        let reported = try #require(viewModel.detail?.match(id: mine.id))
        #expect(reported.status == .reported && reported.reportedBy == TestFixtures.user.id)
        #expect(harness.repository.fetchedIDs.count == fetches + 1, "read back once")
        #expect(harness.presentedError == nil && harness.logs(.error).isEmpty)
        #expect(harness.logs(.info).mentioning("Report result landed for match \(mine.id)", "\(AppError.network)").count == 1)
        #expect(harness.sink.tournaments.count == handedOn + 1 && harness.sink.tournaments.last?.id == "t",
                "the detail read back reaches the lists once")
    }

    @Test func aLostAnswerWhoseRefetchShowsNoResultIsReportedAfterTheRefresh() async throws {
        let (viewModel, mine) = try await startedLeague()
        let fetches = harness.repository.fetchedIDs.count
        let handedOn = harness.sink.tournaments.count
        harness.repository.actionError = AppError.network

        #expect(await viewModel.report(mine, scoreA: 3, scoreB: 1) == false)

        #expect(harness.repository.fetchedIDs.count == fetches + 1 && harness.sink.tournaments.count == handedOn + 1)
        #expect(viewModel.detail?.match(id: mine.id)?.status == .pending)
        #expect(harness.presentedError == .network)
        #expect(harness.logs(.error).mentioning("Report result for tournament t failed", "\(AppError.network)").count == 1)
    }

    @Test func aLostAnswerWhoseRefetchFailsIsReportedAsItWas() async throws {
        let (viewModel, mine) = try await startedLeague()
        let handedOn = harness.sink.tournaments.count
        harness.repository.lostAnswerError = AppError.network
        harness.repository.detailError = AppError.tournamentsUnavailable

        #expect(await viewModel.report(mine, scoreA: 3, scoreB: 1) == false)

        #expect(harness.presentedError == .network, "the write's error, not the read's")
        #expect(harness.logs(.warning).mentioning("Could not read tournament t back", "\(AppError.network)").count == 1)
        #expect(viewModel.detail?.match(id: mine.id)?.status == .pending && harness.sink.tournaments.count == handedOn,
                "the screen keeps what it had")
    }

    @Test func aRefusalIsReportedWithoutAReadBack() async throws {
        let (viewModel, mine) = try await startedLeague()
        let fetches = harness.repository.fetchedIDs.count
        harness.repository.actionError = AppError.matchNotReady

        #expect(await viewModel.report(mine, scoreA: 3, scoreB: 1) == false)

        #expect(harness.repository.fetchedIDs.count == fetches)
        #expect(harness.presentedError == .matchNotReady)
        let refused = harness.logs(.warning).mentioning("Report result for tournament t failed", "\(AppError.matchNotReady)")
        #expect(refused.count == 1)
    }

    /// The route's fallback stands for a 5xx, after which the backend may have committed too.
    @Test func theRoutesFallbackIsReadBackToo() async throws {
        let (viewModel, mine) = try await startedLeague()
        harness.repository.lostAnswerError = AppError.tournamentActionFailed

        #expect(await viewModel.report(mine, scoreA: 3, scoreB: 1))

        #expect(viewModel.detail?.match(id: mine.id)?.status == .reported && harness.presentedError == nil)
    }

    @Test func aLostAnswerToAConfirmIsReadOffTheMatch() async throws {
        let (viewModel, mine) = try await startedLeague()
        let reported = try await reportedByTheOtherSide(viewModel, mine)
        #expect(viewModel.actions(for: reported).canConfirm)
        harness.repository.lostAnswerError = AppError.network

        #expect(await viewModel.confirm(reported))

        let confirmed = try #require(viewModel.detail?.match(id: mine.id))
        #expect(confirmed.status == .confirmed && confirmed.confirmedBy == TestFixtures.user.id)
        #expect(harness.presentedError == nil && harness.repository.confirmedMatchIDs == [mine.id])
    }

    @Test func aLostAnswerToADisputeIsReadOffTheMatch() async throws {
        let (viewModel, mine) = try await startedLeague()
        let reported = try await reportedByTheOtherSide(viewModel, mine)
        harness.repository.lostAnswerError = AppError.network

        #expect(await viewModel.dispute(reported))

        #expect(viewModel.detail?.match(id: mine.id)?.isOpenDispute == true)
        #expect(harness.presentedError == nil && harness.repository.disputedMatchIDs == [mine.id])
    }

    @Test func aLostAnswerToAWalkoverIsReadOffTheMatch() async throws {
        let viewModel = await startedCup()
        let semi = try #require(viewModel.detail?.match(id: "r01p001"))
        harness.repository.lostAnswerError = AppError.network

        #expect(await viewModel.walkover(semi, winnerEntryID: "e1"))

        let decided = try #require(viewModel.detail?.match(id: "r01p001"))
        #expect(decided.status == .walkover && decided.winnerEntryId == "e1")
        #expect(viewModel.detail?.match(id: "r02p001")?.entryAId == "e1", "the winner advanced on the detail read back")
        #expect(harness.presentedError == nil)
    }

    @Test func aLostAnswerToAScheduleIsReadOffTheMatch() async throws {
        let viewModel = await startedCup()
        let semi = try #require(viewModel.detail?.match(id: "r01p001"))
        let tomorrow = TournamentHarness.now.addingTimeInterval(86_400)
        let place = EventLocation(name: "Pitch 2", coordinate: AppConfig.Location.mockCenter)
        harness.repository.lostAnswerError = AppError.network

        #expect(await viewModel.schedule(semi, MatchSchedule(scheduledAt: tomorrow, location: place)))

        let scheduled = try #require(viewModel.detail?.match(id: "r01p001"))
        #expect(scheduled.status == .scheduled && scheduled.scheduledAt == tomorrow && scheduled.location == place)
        #expect(harness.presentedError == nil)
        #expect(harness.logs(.info).mentioning("r01p001", "scheduled").count == 1)
    }

    @Test func aLostAnswerToAScheduleThatNeverLandedIsReported() async throws {
        let viewModel = await startedCup()
        let semi = try #require(viewModel.detail?.match(id: "r01p001"))
        let fetches = harness.repository.fetchedIDs.count
        harness.repository.actionError = AppError.network

        #expect(await viewModel.schedule(semi, MatchSchedule(scheduledAt: TournamentHarness.now, location: nil)) == false)

        #expect(viewModel.detail?.match(id: "r01p001")?.hasSchedule == false)
        #expect(harness.repository.fetchedIDs.count == fetches + 1, "read back once")
        #expect(harness.presentedError == .network && harness.logs(.info).mentioning("r01p001", "scheduled").isEmpty)
    }
}
