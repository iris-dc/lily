import Foundation
import SwiftUI
import Testing
@testable import lily

@MainActor
struct TournamentDetailLoadTests {
    private let harness = TournamentHarness()
    private let destination = TournamentDestination(id: "t", name: "Tuesday Table Tennis")

    /// A pull-to-refresh runs outside the keyed task, so a write can be accepted while it is in flight.
    @Test func aStaleRefreshAnswerNeverOvertakesAnAcceptedWrite() async {
        let (viewModel, refresh) = await loadedWithARefreshHeld()
        let fresh = TournamentDetail.fixture(tournament: .fixture(entryCount: 5))

        viewModel.accept(fresh)
        harness.repository.releaseRequests()
        await refresh.value

        #expect(viewModel.detail == fresh)
        #expect(harness.repository.fetchedIDs.count == 2)
        #expect(harness.sink.tournaments.count == 1, "only the accepted write was handed on")
    }

    /// The failure belongs to a page nobody shows any more.
    @Test func aStaleLoadFailureShowsNoPopupOverAnAcceptedDetail() async {
        let (viewModel, refresh) = await loadedWithARefreshHeld()
        let fresh = TournamentDetail.fixture(tournament: .fixture(entryCount: 5))

        viewModel.accept(fresh)
        harness.repository.thrownError = AppError.network
        harness.repository.releaseRequests()
        await refresh.value

        #expect(viewModel.detail == fresh)
        #expect(harness.presentedError == nil)
        #expect(harness.logs(.error).isEmpty)
    }

    /// A cancelled load or write (the keyed task restarted, the screen left) is nobody's failure.
    @Test func cancellationStaysQuietInLoadAndWrites() async {
        harness.repository.thrownError = CancellationError()
        let viewModel = harness.makeDetailViewModel(for: destination)

        await viewModel.load()

        #expect(viewModel.state == .loading && harness.presentedError == nil)
        #expect(harness.logs().isEmpty)

        harness.repository.thrownError = nil
        harness.repository.details["t"] = .fixture(tournament: .fixture(entryCount: 1))
        await viewModel.load()
        harness.repository.actionError = CancellationError()

        await viewModel.join()

        #expect(viewModel.participation == .join && harness.repository.joins.count == 1)
        #expect(harness.repository.fetchedIDs.count == 2, "no refetch follows a cancelled write")
        #expect(harness.presentedError == nil)
        #expect(harness.logs(.warning).isEmpty && harness.logs(.error).isEmpty)
        #expect(harness.groupRepository.requestedScopes.isEmpty, "Mine is not reloaded")
    }

    @Test func theLinkedMatchShowsAfterTheFirstSuccessfulLoad() async {
        let linked = TournamentDestination(id: "t", name: "Kickers Cup", matchID: "r01p001")
        harness.repository.thrownError = AppError.network
        let viewModel = harness.makeDetailViewModel(for: linked)

        await viewModel.load()
        #expect(viewModel.linkedMatchToShow == nil && viewModel.state == .failed)

        harness.repository.thrownError = nil
        let detail = TournamentDetail.fixture(tournament: .fixture(status: .inProgress), matches: [matchFixture("r01p001")])
        harness.repository.details["t"] = detail
        await viewModel.load()
        #expect(viewModel.linkedMatchToShow == "r01p001")

        viewModel.consumeLinkedMatch()
        #expect(viewModel.linkedMatchToShow == nil)
        await viewModel.load()
        #expect(viewModel.linkedMatchToShow == nil, "a reload never raises it again")
        viewModel.accept(detail)
        #expect(viewModel.linkedMatchToShow == nil, "an own write never raises it again")
    }

    @Test func noLinkedMatchWithoutADestinationMatchOrForAnUnknownOne() async {
        harness.repository.details["t"] = .fixture(tournament: .fixture(status: .inProgress), matches: [matchFixture("r01p001")])
        let plain = harness.makeDetailViewModel(for: destination)
        await plain.load()
        #expect(plain.linkedMatchToShow == nil)

        let unknown = harness.makeDetailViewModel(for: TournamentDestination(id: "t", name: "Kickers Cup", matchID: "r09p009"))
        await unknown.load()
        #expect(unknown.linkedMatchToShow == nil)

        harness.repository.details["t"] = .fixture(tournament: .fixture(status: .inProgress),
                                                   matches: [matchFixture("r01p001"), matchFixture("r09p009")])
        await unknown.load()
        #expect(unknown.linkedMatchToShow == nil, "decided on the first successful load")
    }

    @Test func openChatFailureReachesThePopup() async {
        let entered = Tournament.fixture(entryCount: 1, myEntryId: "e1")
        let mine = TournamentEntry.fixture(id: "e1", captainUserId: TestFixtures.user.id)
        let viewModel = await harness.loadedDetailViewModel(entered, entries: [mine], for: destination)
        harness.groupRepository.thrownError = AppError.network

        await viewModel.openChat()

        #expect(harness.presentedError == .network)
        #expect(harness.navigation.chatPath.isEmpty)
        #expect(harness.logs(.error).contains { $0.contains("Open chat for tournament \(destination.id) failed") })
    }

    private func loadedWithARefreshHeld() async -> (viewModel: TournamentDetailViewModel, refresh: Task<Void, Never>) {
        harness.repository.details["t"] = .fixture(tournament: .fixture(entryCount: 2))
        let viewModel = harness.makeDetailViewModel(for: destination)
        await viewModel.load()
        harness.repository.holdsRequests = true
        let refresh = Task { await viewModel.load() }
        await settle(until: { harness.repository.fetchedIDs.count == 2 })
        return (viewModel, refresh)
    }

    private func matchFixture(_ id: String) -> TournamentMatch {
        TournamentMatch(id: id, tournamentId: "t", round: 1, position: 1, entryAId: "e1", entryBId: "e2")
    }
}
