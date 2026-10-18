import Foundation
import Testing
@testable import lily

/// A card or a tile hands the detail the tournament it showed; the detail draws it until the fetch answers.
@MainActor
struct TournamentDetailPreviewTests {
    private let harness = TournamentHarness()
    private let tournament = Tournament.fixture(name: "Kickers Cup", entryCount: 4)
    private var destination: TournamentDestination { tournament.destination }

    @Test func aCardsDestinationCarriesTheTournamentItShowed() {
        #expect(destination.preview == tournament)
        #expect(destination.id == tournament.id && destination.name == tournament.name && destination.matchID == nil)
        #expect(TournamentDestination(id: "t", name: "Tuesday Table Tennis").preview == nil)
    }

    /// Before the fetch answers the header, the facts and the control read the preview; the detail (entries, matches)
    /// is not there yet.
    @Test func thePreviewIsDrawnUntilTheDetailAnswers() async {
        harness.repository.holdsRequests = true
        let viewModel = harness.makeDetailViewModel(for: destination)
        #expect(viewModel.state == .previewing(tournament))
        #expect(viewModel.tournament == tournament && viewModel.detail == nil)
        #expect(viewModel.name == "Kickers Cup")
        #expect(viewModel.permissions != .none)

        let fresh = TournamentDetail.fixture(tournament: .fixture(name: "Kickers Cup", entryCount: 5))
        harness.repository.details[tournament.id] = fresh
        let load = Task { await viewModel.loadIfNeeded() }
        await settle(until: { harness.repository.isHolding })
        #expect(viewModel.state == .previewing(tournament), "the preview stays while the fetch is out")

        harness.repository.releaseRequests()
        await load.value
        #expect(viewModel.state == .loaded(fresh))
        #expect(viewModel.tournament?.entryCount == 5)
    }

    /// A load that fails while the opener's copy is on screen keeps it, flags the failure for the slot's Try again, and
    /// the retry starts from the copy again, never from the bare spinner; a 404 shows "no longer available" without
    /// dismissing, since nothing was loaded.
    @Test func aFailedLoadKeepsThePreviewAndTryAgainStartsFromIt() async {
        harness.repository.thrownError = AppError.network
        let viewModel = harness.makeDetailViewModel(for: destination)
        await viewModel.load()
        #expect(viewModel.state == .previewing(tournament) && viewModel.previewLoadFailed)
        #expect(harness.presentedError == .network)

        harness.repository.thrownError = nil
        harness.repository.holdsRequests = true
        let retry = Task { await viewModel.load() }
        await settle(until: { harness.repository.isHolding })
        #expect(viewModel.state == .previewing(tournament) && !viewModel.previewLoadFailed)
        harness.repository.details[tournament.id] = .fixture(tournament: tournament)
        harness.repository.releaseRequests()
        await retry.value
        #expect(viewModel.detail != nil)

        harness.repository.thrownError = AppError.tournamentNotFound
        let gone = harness.makeDetailViewModel(for: destination)
        await gone.load()
        #expect(gone.state == .notFound && !gone.isGone)
    }

    /// The screen draws one detail for both states, the loaded one or the copy with nothing under it.
    @Test func theShownDetailIsTheCopyUntilTheLoadedOne() async {
        let viewModel = harness.makeDetailViewModel(for: destination)
        #expect(viewModel.shownDetail == TournamentDetail(tournament: tournament) && viewModel.isPreviewing)

        let fresh = TournamentDetail.fixture(tournament: tournament, entries: [.fixture()])
        harness.repository.details[tournament.id] = fresh
        await viewModel.load()
        #expect(viewModel.shownDetail == fresh && !viewModel.isPreviewing)
    }

    /// The control draws from the copy, so a Join can land while the first fetch is still out: its answer takes the
    /// screen, and the first fetch's late answer is dropped.
    @Test func aJoinFromThePreviewTakesTheScreenAndTheLateFetchIsDropped() async {
        harness.repository.holdsRequests = true
        harness.repository.details[tournament.id] = .fixture(tournament: tournament)
        let viewModel = harness.makeDetailViewModel(for: destination)
        let first = Task { await viewModel.loadIfNeeded() }
        await settle(until: { harness.repository.isHolding })

        harness.repository.holdsRequests = false
        await viewModel.join()

        #expect(harness.repository.joins.count == 1)
        #expect(viewModel.detail != nil && viewModel.participation == .leave)
        let joined = viewModel.detail
        harness.repository.holdsRequests = true
        harness.repository.releaseRequests()
        await first.value
        #expect(viewModel.detail == joined, "the first fetch's late answer never overwrites the join")
    }

    /// An opener with the id alone starts loading, as before.
    @Test func anIdAloneStartsWithTheSpinner() {
        let viewModel = harness.makeDetailViewModel(for: TournamentDestination(id: "t", name: "Tuesday Table Tennis"))

        #expect(viewModel.state == .loading && viewModel.tournament == nil)
        #expect(viewModel.name == "Tuesday Table Tennis")
    }
}
