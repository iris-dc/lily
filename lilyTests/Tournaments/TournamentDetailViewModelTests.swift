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
        #expect(!viewModel.canEdit && !viewModel.canInvite && viewModel.canReport, "an outsider may report")
        #expect(viewModel.showsMenu)
        #expect(viewModel.reportTarget == .tournament(id: "t") && viewModel.winnerName == nil)
    }

    /// The screen's one entry: the first load, a reload only when a tournament changed elsewhere since, never for a
    /// change this screen made itself (its `accept` acknowledges the version the lists are told about).
    @Test func loadIfNeededReloadsOnAChangeMadeElsewhereNotOnItsOwn() async {
        let detail = TournamentDetail.fixture(tournament: .fixture(id: "t", organizerUserId: TestFixtures.user.id))
        harness.repository.details["t"] = detail
        let viewModel = harness.makeDetailViewModel(for: destination)

        await viewModel.loadIfNeeded()
        await viewModel.loadIfNeeded()
        #expect(harness.repository.fetchedIDs == ["t"], "nothing changed since the first load")

        harness.changes.recordChange()
        await viewModel.loadIfNeeded()
        #expect(harness.repository.fetchedIDs == ["t", "t"], "a change elsewhere reloads once")

        viewModel.accept(detail)
        #expect(harness.changes.version == 2, "the lists were told")
        await viewModel.loadIfNeeded()
        #expect(harness.repository.fetchedIDs == ["t", "t"], "an own change costs no request")
    }

    /// A completed tournament names its winner from the entries; an unknown entry names nobody.
    @Test func theWinnerIsNamedFromTheEntriesOnceCompleted() async {
        let marta = TournamentEntry.fixture(id: "e1", name: "Marta")
        let completed = Tournament.fixture(id: "t", status: .inProgress, entryCount: 1).completing(winnerEntryId: "e1", at: .now)
        harness.repository.details["t"] = .fixture(tournament: completed, entries: [marta])
        let viewModel = harness.makeDetailViewModel(for: destination)
        await viewModel.load()
        #expect(viewModel.winnerName == "Marta")

        let unknown = completed.completing(winnerEntryId: "zz", at: .now)
        harness.repository.details["t"] = .fixture(tournament: unknown, entries: [marta])
        await viewModel.load()
        #expect(viewModel.winnerName == nil)
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

    /// A 404 on a reload of a loaded detail means the tournament was deleted meanwhile (an operator): the screen is gone,
    /// its room leaves Mine and the lists behind reload; a first load's 404 only shows the empty state.
    @Test func aTournamentDeletedAfterItLoadedIsGoneAndTellsTheLists() async {
        await harness.loadGroups([.tournamentRoomFixture(id: "t"), .fixture(id: "g")])
        harness.repository.details["t"] = .fixture()
        let viewModel = harness.makeDetailViewModel(for: destination)
        await viewModel.load()
        #expect(!viewModel.isGone && harness.changes.version == 0)

        harness.repository.details["t"] = nil
        await viewModel.load()

        #expect(viewModel.isGone && viewModel.state == .notFound && viewModel.tournament == nil)
        #expect(harness.changes.version == 1, "the lists behind drop the row")
        #expect(harness.groups.groups.map(\.id) == ["g"], "its room left Mine")
        await viewModel.loadIfNeeded()
        #expect(harness.repository.fetchedIDs == ["t", "t"], "a gone screen asks for nothing more")

        let fresh = harness.makeDetailViewModel(for: destination)
        await fresh.load()
        #expect(fresh.state == .notFound && !fresh.isGone, "a stale row's 404 keeps the empty state")
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

    /// The room lands in Mine first, so the Chats split view (which shows only rooms Mine lists) can select it even
    /// while Mine's index still misses a room just entered.
    @Test func openChatFetchesTheRoomPlacesItInMineAndPushesIt() async {
        harness.repository.details["t"] = .fixture(tournament: .fixture(myEntryId: "e"))
        harness.groupRepository.result = .success([.tournamentRoomFixture()])
        let viewModel = harness.makeDetailViewModel(for: destination)
        await viewModel.load()

        await viewModel.openChat()

        #expect(harness.groupRepository.fetchedGroupIDs == ["t"] && harness.navigation.selectedTab == .chat)
        #expect(harness.navigation.chatPath.count == 1)
        #expect(harness.groups.groups.map(\.id) == ["t"])
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
