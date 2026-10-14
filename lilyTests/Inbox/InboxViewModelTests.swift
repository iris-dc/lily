import Foundation
import SwiftUI
import Testing
@testable import lily

@MainActor
struct InboxViewModelTests {
    private let harness = GroupHarness()
    private let invite = InboxItem.invite(id: "i1", groupID: "g3")
    private let reminder = InboxItem.reminder(id: "i0", eventID: "e")

    @Test func appearLoadsTheInboxAndMarksItRead() async {
        let viewModel = await harness.openInbox([reminder, invite])

        #expect(viewModel.rows.count == 3, "one day chip and two cards")
        #expect(viewModel.newestID == invite.id && !viewModel.isInitialLoad && !viewModel.hasOlder)
        #expect(harness.inboxRepository.readMarks == [invite.id] && !harness.inbox.hasUnread)
    }

    /// The spinner comes before the empty state: a screen whose task has yet to start the load is not "empty".
    @Test func aNeverLoadedInboxShowsTheSpinnerFirst() async {
        harness.inboxRepository.pages = [.fixture([])]
        let viewModel = harness.makeInboxViewModel()

        #expect(viewModel.isInitialLoad && !harness.inbox.isLoading, "before the view's task started the load")
        await viewModel.appear()

        #expect(!viewModel.isInitialLoad && viewModel.rows.isEmpty, "the empty state is earned by an answer")
    }

    @Test func aFailingFirstLoadShowsTheFailureNotTheSpinner() async {
        harness.inboxRepository.pageError = AppError.inboxUnavailable
        let viewModel = harness.makeInboxViewModel()

        await viewModel.appear()

        #expect(!viewModel.isInitialLoad && viewModel.loadFailed && harness.presentedError == .inboxUnavailable)
    }

    @Test func acceptingPutsTheGroupIntoMineOpensItsChatAndShowsTheInviteAccepted() async {
        harness.inboxRepository.acceptedGroup = .fixture(id: "g3", visibility: .private, role: .member)
        let viewModel = await harness.openInbox([invite])

        await viewModel.accept(invite)

        #expect(harness.inboxRepository.acceptedItemIDs == ["i1"])
        #expect(harness.store.groups.map(\.id) == ["g3"], "the group shows in Mine at once")
        #expect(harness.navigation.selectedTab == .chat && harness.navigation.chatPath.count == 1)
        #expect(harness.inbox.items.first?.invite?.status == .accepted && !viewModel.isBusy(invite))
        #expect(!harness.inboxLogs(.info).mentioning("i1", "accepted", "group g3").isEmpty && harness.presentedError == nil)
    }

    /// The backend admitted the caller somewhere this build cannot name (contract drift): the card shows its answer,
    /// Mine is reloaded for whatever room that is, and nothing opens.
    @Test func anAcceptanceCarryingNeitherGroupNorTournamentWarnsAndReloads() async {
        harness.inboxRepository.acceptedGroup = nil
        let viewModel = await harness.openInbox([invite])

        await viewModel.accept(invite)

        #expect(harness.inbox.items.first?.invite?.status == .accepted, "the backend's answer is shown")
        #expect(harness.repository.requestedScopes == [.mine], "Mine reloaded once")
        #expect(harness.store.groups.isEmpty && harness.navigation.homePath.isEmpty && harness.navigation.chatPath.isEmpty)
        #expect(harness.presentedError == nil && harness.tournamentChanges.version == 0 && !viewModel.isBusy(invite))
        let warnings = harness.inboxLogs(.warning)
        #expect(warnings.count == 1 && warnings.first?.contains("accepted into nothing this build knows") == true)
    }

    @Test func aLostRaceIsRepeatedOnceAndASecondOneIsShown() async {
        harness.inboxRepository.transientAcceptErrors = [.tryAgain]
        let viewModel = await harness.openInbox([invite])

        await viewModel.accept(invite)
        #expect(harness.inboxRepository.acceptedItemIDs == ["i1", "i1"] && harness.presentedError == nil)
        #expect(!harness.inboxLogs(.info).mentioning("i1", "lost a race").isEmpty)

        harness.inboxRepository.transientAcceptErrors = [.tryAgain, .tryAgain]
        await viewModel.accept(invite)
        #expect(harness.inboxRepository.acceptedItemIDs.count == 4 && harness.presentedError == .tryAgain)
    }

    @Test func decliningShowsTheInviteDeclinedAndOpensNothing() async {
        let viewModel = await harness.openInbox([invite])

        await viewModel.decline(invite)

        #expect(harness.inboxRepository.declinedItemIDs == ["i1"])
        #expect(harness.inbox.items.first?.invite?.status == .declined)
        #expect(harness.store.groups.isEmpty && harness.navigation.chatPath.isEmpty)
        #expect(!harness.inboxLogs(.info).mentioning("i1", "declined").isEmpty)
    }

    /// A verdict on the invite reaches the popup and the inbox is fetched again, so the card follows the backend.
    @Test func anExpiredInviteShowsThePopupAndReloadsTheInbox() async {
        let viewModel = await harness.openInbox([invite])
        let expired = invite.responding(.declined, at: harness.inboxRepository.now)
        harness.inboxRepository.acceptError = AppError.inviteExpired
        harness.inboxRepository.pages = [.fixture([expired])]

        await viewModel.accept(invite)

        #expect(harness.presentedError == .inviteExpired)
        #expect(harness.inboxRepository.pageRequests.count == 2 && harness.inbox.items == [expired])
        #expect(harness.inboxLogs(.warning).mentioning("i1", "\(AppError.inviteExpired)").count == 1)
        #expect(harness.inboxLogs(.error).isEmpty)
    }

    /// An item the backend no longer holds is a verdict like an expired invite: shown, the inbox refetched, nothing
    /// opened.
    @Test func anUnknownItemIdIsNotPending() async {
        let viewModel = await harness.openInbox([invite])
        harness.inboxRepository.items = []

        await viewModel.accept(invite)

        #expect(harness.inboxRepository.acceptedItemIDs == ["i1"] && harness.presentedError == .inviteNotPending)
        #expect(harness.inboxRepository.pageRequests.count == 2, "the verdict reloads the inbox")
        #expect(harness.store.groups.isEmpty && harness.navigation.chatPath.isEmpty && !viewModel.isBusy(invite))
        #expect(harness.inboxLogs(.warning).mentioning("i1", "\(AppError.inviteNotPending)").count == 1)
    }

    /// An unknown outcome is shown and nothing is refetched: a repeated accept is safe, the backend replays it.
    @Test func aLostConnectionIsShownWithoutAReload() async {
        let viewModel = await harness.openInbox([invite])
        harness.inboxRepository.acceptError = AppError.network

        await viewModel.accept(invite)

        #expect(harness.presentedError == .network && harness.inboxRepository.pageRequests.count == 1)
        #expect(harness.inbox.items.first?.invite?.status == .pending)
        #expect(harness.inboxLogs(.error).mentioning("i1", "\(AppError.network)").count == 1)
    }

    @Test func aTermsRefusalRaisesTheTermsSheet() async {
        let viewModel = await harness.openInbox([invite])
        harness.inboxRepository.acceptError = AppError.termsRequired

        await viewModel.accept(invite)

        #expect(harness.presentedError == .termsRequired && harness.termsRequiredCount == 1)
    }

    /// One answer per invite at a time: a second tap while the first is out is dropped.
    @Test func aBusyInviteIgnoresASecondTap() async {
        let viewModel = await harness.openInbox([invite])
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
        let viewModel = await harness.openInbox([reminder])

        await viewModel.openEvent(for: reminder)

        #expect(harness.events.fetchedEventIDs == ["e"])
        #expect(harness.navigation.selectedTab == .chat && harness.navigation.chatPath.count == 1)
        #expect(!viewModel.isBusy(reminder))
    }

    @Test func aReminderThatOpenedItsGameIsLogged() async {
        harness.events.result = .success([.fixture(id: "e")])
        let viewModel = await harness.openInbox([reminder])

        await viewModel.openEvent(for: reminder)

        #expect(!harness.inboxLogs(.info).mentioning("i0", "opened", "game e").isEmpty)
    }

    /// One game fetch per reminder at a time: a second tap while the first is out is dropped.
    @Test func aSecondReminderTapWhileTheGameLoadsIsDropped() async {
        harness.events.result = .success([.fixture(id: "e")])
        let viewModel = await harness.openInbox([reminder])
        harness.events.holdsRequests = true

        let first = Task { await viewModel.openEvent(for: reminder) }
        await settle(until: { harness.events.fetchedEventIDs.count == 1 })
        #expect(viewModel.isBusy(reminder))
        await viewModel.openEvent(for: reminder)
        #expect(harness.events.fetchedEventIDs.count == 1, "the second tap fetched nothing")
        harness.events.releaseRequests()
        await first.value

        #expect(harness.events.fetchedEventIDs == ["e"] && harness.navigation.chatPath.count == 1)
        #expect(!viewModel.isBusy(reminder))
    }

    @Test func aGoneGameReachesThePopupAndAnInviteOpensNoGame() async {
        harness.events.result = .success([])
        let viewModel = await harness.openInbox([reminder, invite])

        await viewModel.openEvent(for: reminder)
        await viewModel.openEvent(for: invite)

        #expect(harness.presentedError == .eventNotFound && harness.navigation.chatPath.isEmpty)
        #expect(harness.events.fetchedEventIDs == ["e"])
        #expect(harness.logger.messages(in: .events, at: .warning).count == 1)
        #expect(!harness.inboxLogs(.info).contains { $0.contains("opened game") })
    }

    /// An item that lands while the inbox is open counts as seen.
    @Test func aLiveItemWhileOpenIsMarkedRead() async {
        let viewModel = await harness.openInbox([reminder])
        let newer = InboxItem.invite(id: "i9")

        harness.inbox.apply(newer)
        #expect(viewModel.newestID == "i9" && harness.inbox.hasUnread)
        await viewModel.noteNewItems()

        #expect(harness.inboxRepository.readMarks == [reminder.id, "i9"] && !harness.inbox.hasUnread)
    }

    @Test func refreshReloadsAndMarksRead() async {
        let viewModel = await harness.openInbox([reminder])
        harness.inboxRepository.pages = [.fixture([reminder, invite])]

        await viewModel.refresh()

        #expect(harness.inbox.items.count == 2 && harness.inboxRepository.readMarks == [reminder.id, invite.id])
    }
}
