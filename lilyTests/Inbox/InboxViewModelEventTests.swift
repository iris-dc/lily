import Foundation
import SwiftUI
import Testing
@testable import lily

/// The event branches of the inbox: an accept opens the joined game's detail on Home and reloads the event lists and
/// Mine; refusals and declines mirror the group and tournament branches.
@MainActor
struct InboxViewModelEventTests {
    private let harness = GroupHarness()
    private let invite = InboxItem.eventInvite(id: "i1", eventID: "e1", title: "Sunset 5-a-side")

    @Test func acceptingOpensTheDetailOnHomeAndReloadsTheListsAndMine() async {
        harness.inboxRepository.acceptedEvent = .fixture(id: "e1", title: "Sunset 5-a-side", isJoined: true)
        let viewModel = await harness.openInbox([invite])

        await viewModel.accept(invite)

        #expect(harness.inboxRepository.acceptedItemIDs == ["i1"])
        #expect(harness.navigation.selectedTab == .home && harness.navigation.homePath.count == 1, "the detail, on Home")
        #expect(harness.navigation.chatPath.isEmpty && harness.repository.requestedScopes == [.mine],
                "Mine reloads for the room")
        #expect(harness.eventChanges.version == 1 && harness.tournamentChanges.version == 0 && harness.changes.version == 0)
        #expect(harness.inbox.items.first?.eventInvite?.status == .accepted && !viewModel.isBusy(invite))
        #expect(harness.inboxLogs(.info).contains("Invite i1 accepted into event e1"))
        #expect(harness.presentedError == nil)
    }

    /// The by-user index may lag the acceptance transaction: the fetchable member room is placed in Mine directly,
    /// the event detail's join recipe.
    @Test func acceptingPlacesTheFetchableRoomInMine() async {
        harness.inboxRepository.acceptedEvent = .fixture(id: "e1", title: "Sunset 5-a-side", isJoined: true)
        harness.repository.result = .success([SportGroup.eventRoomFixture(id: "e1", role: .member)])
        let viewModel = await harness.openInbox([invite])

        await viewModel.accept(invite)

        #expect(harness.repository.requestedScopes == [.mine] && harness.repository.fetchedGroupIDs == ["e1"])
        #expect(harness.store.groups.map(\.id) == ["e1"])
        #expect(harness.presentedError == nil)
    }

    /// A room the backend cannot serve yet keeps quiet: Mine's reload stands as the fallback, nothing is reported
    /// and the detail still opens.
    @Test func aRoomFetchFailureLeavesMinesReloadStanding() async {
        harness.inboxRepository.acceptedEvent = .fixture(id: "e1", title: "Sunset 5-a-side", isJoined: true)
        let viewModel = await harness.openInbox([invite])

        await viewModel.accept(invite)

        #expect(harness.repository.fetchedGroupIDs == ["e1"] && harness.store.groups.isEmpty)
        #expect(harness.presentedError == nil)
        #expect(harness.navigation.selectedTab == .home && harness.navigation.homePath.count == 1, "the detail still opens")
        #expect(harness.inboxLogs(.debug).contains { $0.contains("no fetchable room") })
    }

    /// The accept landed but its answer was lost: the read-back shows the invite accepted, so the event lists are told
    /// and Mine reloaded as a direct accept does; nothing opens and nothing is reported.
    @Test func aLostAnswerWhoseReadBackShowsTheInviteAcceptedBumpsTheListsAndReloadsMine() async {
        let viewModel = await harness.openInbox([invite])
        harness.inboxRepository.acceptError = AppError.network
        harness.inboxRepository.pages = [.fixture([invite.responding(.accepted, at: harness.inboxRepository.now)])]

        await viewModel.accept(invite)

        #expect(harness.presentedError == nil && harness.inbox.items.first?.eventInvite?.status == .accepted)
        #expect(harness.eventChanges.version == 1 && harness.repository.requestedScopes == [.mine])
        #expect(harness.navigation.homePath.isEmpty && harness.navigation.chatPath.isEmpty)
    }

    /// The join refusals on an accept are shown and leave the card as it is; no list is told.
    @Test func aFullGamesRefusalIsShownAndChangesNothing() async {
        let viewModel = await harness.openInbox([invite])
        harness.inboxRepository.acceptError = AppError.eventFull

        await viewModel.accept(invite)

        #expect(harness.presentedError == .eventFull)
        #expect(harness.inbox.items.first?.eventInvite?.status == .pending)
        #expect(harness.eventChanges.version == 0 && harness.inboxRepository.pageRequests.count == 1)
        #expect(harness.navigation.homePath.isEmpty)
    }

    @Test func decliningMarksItDeclinedAndOpensNothing() async {
        let viewModel = await harness.openInbox([invite])

        await viewModel.decline(invite)

        #expect(harness.inboxRepository.declinedItemIDs == ["i1"])
        #expect(harness.inbox.items.first?.eventInvite?.status == .declined)
        #expect(harness.navigation.homePath.isEmpty && harness.navigation.chatPath.isEmpty)
    }
}
