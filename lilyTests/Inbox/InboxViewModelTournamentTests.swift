import Foundation
import SwiftUI
import Testing
@testable import lily

/// The tournament branches of the inbox: an accept opens the detail (entered, or ready to pick a team) and reloads the
/// tournament lists; a match reminder opens the tournament with its match named. The group branches are in
/// `InboxViewModelTests`.
@MainActor
struct InboxViewModelTournamentTests {
    private let harness = GroupHarness()
    private let invite = InboxItem.tournamentInvite(id: "i1", tournamentID: "t1", tournamentName: "Padel Open")
    private let reminder = InboxItem.matchReminder(id: "i0", tournamentID: "t2", matchID: "r03p002")

    private func openInbox(_ items: [InboxItem]) async -> InboxViewModel {
        harness.inboxRepository.pages = [.fixture(items)]
        harness.inboxRepository.items = items
        let viewModel = harness.makeInboxViewModel()
        await viewModel.appear()
        return viewModel
    }

    @Test func acceptingAnIndividualInviteOpensTheDetailEnteredAndReloadsTheLists() async {
        harness.inboxRepository.acceptedTournament = .fixture(id: "t1", name: "Padel Open", myEntryId: "e9")
        let viewModel = await openInbox([invite])

        await viewModel.accept(invite)

        #expect(harness.inboxRepository.acceptedItemIDs == ["i1"])
        #expect(harness.navigation.selectedTab == .home && harness.navigation.homePath.count == 1, "the detail, on Home")
        #expect(harness.navigation.chatPath.isEmpty && harness.repository.requestedScopes == [.mine], "Mine reloads for the room")
        #expect(harness.tournamentChanges.version == 1 && harness.changes.version == 0)
        #expect(harness.inbox.items.first?.tournamentInvite?.status == .accepted && !viewModel.isBusy(invite))
        #expect(harness.inboxLogs(.info).contains("Invite i1 accepted into tournament t1 as entry e9"))
        #expect(harness.presentedError == nil)
    }

    /// A team tournament's accept enters nobody: the detail opens for the caller to create or join a team.
    @Test func acceptingATeamInviteOpensTheDetailWithoutAnEntry() async {
        harness.inboxRepository.acceptedTournament = .fixture(id: "t1", name: "Kickers Cup", teamSize: 5)
        let team = InboxItem.tournamentInvite(id: "i1", tournamentID: "t1", tournamentName: "Kickers Cup", teamSize: 5)
        let viewModel = await openInbox([team])

        await viewModel.accept(team)

        #expect(harness.navigation.selectedTab == .home && harness.navigation.homePath.count == 1)
        #expect(harness.tournamentChanges.version == 1 && harness.repository.requestedScopes.isEmpty, "no room to reload for")
        #expect(harness.inboxLogs(.info).contains("Invite i1 accepted into tournament t1"))
        #expect(!harness.inboxLogs(.info).contains { $0.contains("as entry") })
    }

    /// The entry refusals on an accept are shown and leave the item as it is; a verdict on the invite reloads.
    @Test func refusalsAreShownAndAVerdictReloads() async {
        let viewModel = await openInbox([invite])
        harness.inboxRepository.acceptError = AppError.registrationClosed

        await viewModel.accept(invite)
        #expect(harness.presentedError == .registrationClosed && harness.inboxRepository.pageRequests.count == 1)
        #expect(harness.inbox.items.first?.tournamentInvite?.status == .pending && harness.tournamentChanges.version == 0)

        harness.inboxRepository.acceptError = AppError.inviteNotPending
        harness.inboxRepository.pages = [.fixture([invite.responding(.declined, at: harness.inboxRepository.now)])]
        await viewModel.accept(invite)
        #expect(harness.presentedError == .inviteNotPending && harness.inboxRepository.pageRequests.count == 2)
        #expect(harness.inbox.items.first?.tournamentInvite?.status == .declined)
    }

    @Test func decliningATournamentInviteMarksItDeclined() async {
        let viewModel = await openInbox([invite])

        await viewModel.decline(invite)

        #expect(harness.inboxRepository.declinedItemIDs == ["i1"])
        #expect(harness.inbox.items.first?.tournamentInvite?.status == .declined && harness.navigation.homePath.isEmpty)
    }

    /// The reminder card pushes the destination it carries; nothing is fetched here, the detail does that.
    @Test func openTournamentPushesTheMatchOnTheChatsStackWithoutAFetch() async {
        let viewModel = await openInbox([reminder, invite])

        viewModel.openTournament(for: reminder)
        viewModel.openTournament(for: invite)

        #expect(harness.navigation.selectedTab == .chat && harness.navigation.chatPath.count == 1)
        #expect(harness.inboxLogs(.info).contains("Reminder i0 opened match r03p002 of tournament t2"))
        #expect(!viewModel.isBusy(reminder))
    }
}
