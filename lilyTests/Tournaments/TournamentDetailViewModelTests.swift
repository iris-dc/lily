import Foundation
import SwiftUI
import Testing
@testable import lily

@MainActor
struct TournamentDetailViewModelTests {
    private let harness = TournamentHarness()
    private let destination = TournamentDestination(id: "t", name: "Tuesday Table Tennis")

    @Test func loadFetchesByIdRecordsTheViewAndDecidesTheRole() async {
        harness.repository.details["t"] = .fixture(tournament: .fixture(organizerUserId: "seed-marta"))
        let viewModel = harness.makeDetailViewModel(for: destination)
        #expect(viewModel.name == "Tuesday Table Tennis" && viewModel.state == .loading && viewModel.participation == .hidden)

        await viewModel.load()
        await viewModel.load()

        #expect(viewModel.tournament?.id == "t" && viewModel.role == .outsider && viewModel.participation == .join)
        #expect(harness.recorder.kinds == [.tournamentViewed], "one view per screen instance")
        let interaction = harness.recorder.interactions.first
        #expect(interaction?.tournamentId == "t" && interaction?.tournamentFormat == .roundRobin)
        #expect(interaction?.eventType == .tableTennis)
        #expect(viewModel.organizerProfile?.userId == "seed-marta" && viewModel.showsEntries)
        #expect(!viewModel.canEdit && !viewModel.showsMenu)
    }

    @Test func aMissingTournamentIsNotFoundAndAFailureKeepsTheLastDetail() async {
        let viewModel = harness.makeDetailViewModel(for: destination)
        await viewModel.load()
        #expect(viewModel.state == .notFound)

        harness.repository.details["t"] = .fixture()
        let second = harness.makeDetailViewModel(for: destination)
        await second.load()
        harness.repository.detailError = AppError.network
        await second.load()
        #expect(second.tournament != nil && harness.presentedError == .network, "the loaded detail stays on a failed reload")

        let third = harness.makeDetailViewModel(for: TournamentDestination(id: "x", name: "x"))
        await third.load()
        #expect(third.state == .failed)
    }

    @Test func theOrganiserGetsEditCancelAndTheMenuUntilTheTournamentIsOver() async {
        harness.repository.details["t"] = .fixture(tournament: .fixture(organizerUserId: TestFixtures.user.id))
        let viewModel = harness.makeDetailViewModel(for: destination)
        await viewModel.load()
        #expect(viewModel.role == .organizer && viewModel.canEdit && viewModel.canCancel && viewModel.canRemoveEntries)
        #expect(viewModel.canOpenChat && viewModel.showsMenu && viewModel.organizerProfile == nil)

        await viewModel.cancel()
        #expect(viewModel.tournament?.status == .cancelled && !viewModel.canEdit && !viewModel.canCancel)
        #expect(harness.sink.tournaments.last?.status == .cancelled && harness.repository.cancelledIDs == ["t"])
        #expect(harness.logs(.info).contains { $0.contains("cancelled") })
    }

    @Test func openChatFetchesTheRoomAndPushesIt() async {
        harness.repository.details["t"] = .fixture(tournament: .fixture(myEntryId: "e"))
        harness.groupRepository.result = .success([.tournamentRoomFixture()])
        let viewModel = harness.makeDetailViewModel(for: destination)
        await viewModel.load()

        await viewModel.openChat()

        #expect(harness.groupRepository.fetchedGroupIDs == ["t"] && harness.navigation.selectedTab == .chat)
        #expect(harness.navigation.chatPath.count == 1)
    }

    @Test func aGuestCannotActAndSeesNoEntries() async {
        harness.identity.currentUserID = nil
        harness.repository.details["t"] = .fixture()
        let viewModel = harness.makeDetailViewModel(for: destination)
        await viewModel.load()
        #expect(viewModel.role == .guest && viewModel.participation == .hidden && !viewModel.showsEntries)

        await viewModel.join()
        #expect(harness.repository.joins.isEmpty && viewModel.organizerProfile == nil)
    }

    @Test func aTermsRefusalRaisesTheTermsSheet() async {
        harness.repository.details["t"] = .fixture(tournament: .fixture(organizerUserId: TestFixtures.user.id))
        harness.repository.actionError = AppError.termsRequired
        let viewModel = harness.makeDetailViewModel(for: destination)
        await viewModel.load()

        await viewModel.cancel()

        #expect(harness.presentedError == .termsRequired && harness.termsRequiredCount == 1)
    }

    @Test func aTryAgainIsRepeatedOnce() async {
        harness.repository.details["t"] = .fixture(tournament: .fixture(organizerUserId: TestFixtures.user.id))
        harness.repository.transientErrors = [.tryAgain]
        let viewModel = harness.makeDetailViewModel(for: destination)
        await viewModel.load()

        await viewModel.cancel()

        #expect(harness.repository.cancelledIDs.count == 2 && viewModel.tournament?.status == .cancelled)
        #expect(harness.logs(.info).contains { $0.contains("lost a race") })
    }
}
