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
        let permissions = viewModel.permissions
        #expect(permissions.organizerProfile?.userId == "seed-marta" && permissions.showsEntries)
        #expect(!permissions.canEdit && !permissions.canInvite && permissions.canReport, "an outsider may report")
        #expect(permissions.showsMenu)
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

    /// The keyed task is cancelled by a push over the detail and re-runs with the same version on return: a reload that
    /// settled nothing is asked again.
    @Test func aReloadCancelledByADisappearanceIsAskedAgainOnReturn() async {
        let detail = TournamentDetail.fixture(tournament: .fixture(id: "t"))
        harness.repository.details["t"] = detail
        let viewModel = harness.makeDetailViewModel(for: destination)
        await viewModel.loadIfNeeded()
        harness.changes.recordChange()
        harness.repository.holdsRequests = true
        let reload = Task { await viewModel.loadIfNeeded() }
        await settle(until: { harness.repository.fetchedIDs.count == 2 })

        reload.cancel()
        harness.repository.releaseRequests()
        await reload.value
        await viewModel.loadIfNeeded()

        #expect(harness.repository.fetchedIDs == ["t", "t", "t"], "the change is heard again on return")
        #expect(viewModel.detail == detail && harness.presentedError == nil && harness.logs(.error).isEmpty)
    }

    /// A reload that failed stays acknowledged: Try again and the pull cover it, and a return from a pushed profile
    /// raises no second popup.
    @Test func aReloadThatFailedStaysAcknowledgedUntilTheNextChange() async {
        harness.repository.details["t"] = .fixture(tournament: .fixture(id: "t"))
        let viewModel = harness.makeDetailViewModel(for: destination)
        await viewModel.loadIfNeeded()
        harness.changes.recordChange()
        harness.repository.detailError = AppError.network

        await viewModel.loadIfNeeded()
        #expect(harness.presentedError == .network)
        await viewModel.loadIfNeeded()
        #expect(harness.repository.fetchedIDs.count == 2, "a reported failure is not asked again until the next change")
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
        let permissions = viewModel.permissions
        #expect(viewModel.role == .organizer && permissions.canEdit && permissions.canCancel && permissions.canRemoveEntries)
        #expect(permissions.canOpenChat && permissions.showsMenu && permissions.organizerProfile == nil)

        await viewModel.cancel()
        let afterCancel = viewModel.permissions
        #expect(viewModel.tournament?.status == .cancelled && !afterCancel.canEdit && !afterCancel.canCancel)
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
        #expect(viewModel.role == .guest && viewModel.participation == .hidden && !viewModel.permissions.showsEntries)

        await viewModel.join()
        #expect(harness.repository.joins.isEmpty && viewModel.permissions.organizerProfile == nil)
    }

    @Test func aTermsRefusalReachesThePopup() async {
        harness.repository.details["t"] = .fixture(tournament: .fixture(organizerUserId: TestFixtures.user.id))
        harness.repository.actionError = AppError.termsRequired
        let viewModel = harness.makeDetailViewModel(for: destination)
        await viewModel.load()

        await viewModel.cancel()

        #expect(harness.presentedError == .termsRequired)
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
