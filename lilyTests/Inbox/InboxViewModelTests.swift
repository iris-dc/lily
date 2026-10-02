import Foundation
import SwiftUI
import Testing
@testable import lily

@MainActor
struct InboxViewModelTests {
    private let harness = GroupHarness()
    private let invite = InboxItem.invite(id: "i1", groupID: "g3")
    private let reminder = InboxItem.reminder(id: "i0", eventID: "e")

    /// A view model over an inbox holding `items`, opened once.
    private func openInbox(_ items: [InboxItem]) async -> InboxViewModel {
        harness.inboxRepository.pages = [.fixture(items)]
        harness.inboxRepository.items = items
        let viewModel = harness.makeInboxViewModel()
        await viewModel.appear()
        return viewModel
    }

    @Test func appearLoadsTheInboxAndMarksItRead() async {
        let viewModel = await openInbox([reminder, invite])

        #expect(viewModel.rows.count == 3, "one day chip and two cards")
        #expect(viewModel.newestID == invite.id && !viewModel.isInitialLoad && !viewModel.hasOlder)
        #expect(harness.inboxRepository.readMarks == [invite.id] && !harness.inbox.hasUnread)
    }

    @Test func acceptingPutsTheGroupIntoMineOpensItsChatAndShowsTheInviteAccepted() async {
        harness.inboxRepository.acceptedGroup = .fixture(id: "g3", visibility: .private, role: .member)
        let viewModel = await openInbox([invite])

        await viewModel.accept(invite)

        #expect(harness.inboxRepository.acceptedItemIDs == ["i1"])
        #expect(harness.store.groups.map(\.id) == ["g3"], "the group shows in Mine at once")
        #expect(harness.navigation.selectedTab == .chat && harness.navigation.chatPath.count == 1)
        #expect(harness.inbox.items.first?.invite?.status == .accepted && !viewModel.isBusy(invite))
        #expect(harness.inboxLogs(.info).contains("Invite i1 accepted into group g3") && harness.presentedError == nil)
    }

    @Test func aLostRaceIsRepeatedOnceAndASecondOneIsShown() async {
        harness.inboxRepository.transientAcceptErrors = [.tryAgain]
        let viewModel = await openInbox([invite])

        await viewModel.accept(invite)
        #expect(harness.inboxRepository.acceptedItemIDs == ["i1", "i1"] && harness.presentedError == nil)
        #expect(harness.inboxLogs(.info).contains("Invite i1 accept lost a race; retrying once"))

        harness.inboxRepository.transientAcceptErrors = [.tryAgain, .tryAgain]
        await viewModel.accept(invite)
        #expect(harness.inboxRepository.acceptedItemIDs.count == 4 && harness.presentedError == .tryAgain)
    }

    @Test func decliningShowsTheInviteDeclinedAndOpensNothing() async {
        let viewModel = await openInbox([invite])

        await viewModel.decline(invite)

        #expect(harness.inboxRepository.declinedItemIDs == ["i1"])
        #expect(harness.inbox.items.first?.invite?.status == .declined)
        #expect(harness.store.groups.isEmpty && harness.navigation.chatPath.isEmpty)
        #expect(harness.inboxLogs(.info).contains("Invite i1 declined"))
    }

    /// A verdict on the invite reaches the popup and the inbox is fetched again, so the card follows the backend.
    @Test func anExpiredInviteShowsThePopupAndReloadsTheInbox() async {
        let viewModel = await openInbox([invite])
        let expired = invite.responding(.declined, at: harness.inboxRepository.now)
        harness.inboxRepository.acceptError = AppError.inviteExpired
        harness.inboxRepository.pages = [.fixture([expired])]

        await viewModel.accept(invite)

        #expect(harness.presentedError == .inviteExpired)
        #expect(harness.inboxRepository.pageRequests.count == 2 && harness.inbox.items == [expired])
        #expect(harness.inboxLogs(.error).count == 1)
    }

    /// An unknown outcome is shown and nothing is refetched: a repeated accept is safe, the backend replays it.
    @Test func aLostConnectionIsShownWithoutAReload() async {
        let viewModel = await openInbox([invite])
        harness.inboxRepository.acceptError = AppError.network

        await viewModel.accept(invite)

        #expect(harness.presentedError == .network && harness.inboxRepository.pageRequests.count == 1)
        #expect(harness.inbox.items.first?.invite?.status == .pending)
    }

    @Test func aTermsRefusalRaisesTheTermsSheet() async {
        let viewModel = await openInbox([invite])
        harness.inboxRepository.acceptError = AppError.termsRequired

        await viewModel.accept(invite)

        #expect(harness.presentedError == .termsRequired && harness.termsRequiredCount == 1)
    }

    /// One answer per invite at a time: a second tap while the first is out is dropped.
    @Test func aBusyInviteIgnoresASecondTap() async {
        let viewModel = await openInbox([invite])
        harness.inboxRepository.holdsRequests = true

        let first = Task { await viewModel.accept(invite) }
        await settle(until: { harness.inboxRepository.acceptedItemIDs.count == 1 })
        #expect(viewModel.isBusy(invite))
        await viewModel.accept(invite)
        harness.inboxRepository.releaseRequests()
        await first.value

        #expect(harness.inboxRepository.acceptedItemIDs == ["i1"] && !viewModel.isBusy(invite))
    }

    @Test func openEventFetchesTheGameAndPushesItOnTheChatsStack() async {
        harness.events.result = .success([.fixture(id: "e")])
        let viewModel = await openInbox([reminder])

        await viewModel.openEvent(for: reminder)

        #expect(harness.events.fetchedEventIDs == ["e"])
        #expect(harness.navigation.selectedTab == .chat && harness.navigation.chatPath.count == 1)
        #expect(!viewModel.isBusy(reminder))
    }

    @Test func aGoneGameReachesThePopupAndAnInviteOpensNoGame() async {
        harness.events.result = .success([])
        let viewModel = await openInbox([reminder, invite])

        await viewModel.openEvent(for: reminder)
        await viewModel.openEvent(for: invite)

        #expect(harness.presentedError == .eventNotFound && harness.navigation.chatPath.isEmpty)
        #expect(harness.events.fetchedEventIDs == ["e"])
        #expect(harness.logger.messages(in: .events, at: .warning).count == 1)
    }

    /// An item that lands while the inbox is open counts as seen.
    @Test func aLiveItemWhileOpenIsMarkedRead() async {
        let viewModel = await openInbox([reminder])
        let newer = InboxItem.invite(id: "i9")

        harness.inbox.apply(newer)
        #expect(viewModel.newestID == "i9" && harness.inbox.hasUnread)
        await viewModel.noteNewItems()

        #expect(harness.inboxRepository.readMarks == [reminder.id, "i9"] && !harness.inbox.hasUnread)
    }

    @Test func refreshReloadsAndMarksRead() async {
        let viewModel = await openInbox([reminder])
        harness.inboxRepository.pages = [.fixture([reminder, invite])]

        await viewModel.refresh()

        #expect(harness.inbox.items.count == 2 && harness.inboxRepository.readMarks == [reminder.id, invite.id])
    }
}
