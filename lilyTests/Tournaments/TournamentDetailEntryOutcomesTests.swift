import Foundation
import Testing
@testable import lily

/// The refetch after an entry write, and the read-back after a lost answer or a refusal. A landed write must not leave a
/// stale control on screen, a lost answer is settled by the fresh detail, and a 404 means the tournament is gone.
@MainActor
struct TournamentDetailEntryOutcomesTests {
    private let harness = TournamentHarness()
    private let destination = TournamentDestination(id: "t", name: "Tuesday Table Tennis")

    /// No popup: the write landed. The recorded change makes the view's keyed task reload, which repairs the screen.
    @Test func aFailedRefetchAfterALandedEntryWriteInvalidatesTheLists() async {
        let viewModel = await harness.loadedDetailViewModel(.fixture(entryCount: 1), for: destination)
        harness.repository.detailError = AppError.network
        let version = harness.changes.version

        await viewModel.join()

        #expect(harness.repository.joins.count == 1 && harness.presentedError == nil)
        #expect(harness.logs(.warning).contains { $0.contains("after a write: network") })
        #expect(harness.changes.version == version + 1)
        #expect(harness.sink.tournaments.isEmpty, "nothing stale is handed on")
        #expect(viewModel.participation == .join, "the stale detail stays until the reload")
        #expect(harness.groupRepository.requestedScopes == [.mine], "the entry landed, so the room did too")

        harness.repository.detailError = nil
        await viewModel.loadIfNeeded()
        #expect(harness.repository.fetchedIDs.count == 3 && viewModel.participation == .leave)
    }

    /// A 404 here means the caller lost the hosting group's membership or an operator deleted the tournament.
    @Test func aRefetchThatFindsNothingMarksGone() async {
        await harness.loadGroups([.tournamentRoomFixture(id: "t")])
        let entered = Tournament.fixture(entryCount: 1, myEntryId: "e1")
        let mine = TournamentEntry.fixture(id: "e1", captainUserId: TestFixtures.user.id)
        let viewModel = await harness.loadedDetailViewModel(entered, entries: [mine], for: destination)
        harness.repository.detailError = AppError.tournamentNotFound
        let version = harness.changes.version

        await viewModel.leave()

        #expect(viewModel.isGone && viewModel.state == .notFound)
        #expect(harness.groups.groups.isEmpty && harness.presentedError == nil)
        #expect(harness.changes.version > version)
        #expect(harness.logs(.info).contains { $0.contains("is not available") })
    }

    @Test func leaveWithoutAnEntryAsksNothing() async {
        let viewModel = await harness.loadedDetailViewModel(.fixture(), for: destination)

        await viewModel.leave()

        #expect(harness.repository.leaves.isEmpty && harness.repository.fetchedIDs.count == 1)
        #expect(harness.presentedError == nil)
    }

    /// The control is released before the permission prompt comes up, so Join never spins behind the alert.
    @Test func thePushPromptComesAfterTheControlIsReleased() async {
        let spy = SpyPushOptIn()
        let viewModel = await harness.loadedDetailViewModel(.fixture(entryCount: 1), for: destination, pushOptIn: spy)
        var busyAtOffer: [Bool] = []
        spy.onOffer = { busyAtOffer.append(viewModel.isBusy) }

        await viewModel.join()

        #expect(busyAtOffer == [false] && spy.offerCount == 1)
        #expect(viewModel.participation == .leave)
    }

    /// The backend commits before it answers: the fresh detail shows the entry, so the join counts as landed, with Mine
    /// reloaded and the reminders offered as after a direct answer, and no popup.
    @Test func aLostAnswerOnAJoinThatLandedReportsNothing() async {
        let spy = SpyPushOptIn()
        let viewModel = await harness.loadedDetailViewModel(.fixture(entryCount: 1), for: destination, pushOptIn: spy)
        harness.repository.lostAnswerError = AppError.network
        let version = harness.changes.version

        await viewModel.join()

        #expect(harness.repository.joins.count == 1 && harness.repository.fetchedIDs.count == 2, "one read-back")
        #expect(harness.presentedError == nil && viewModel.participation == .leave)
        #expect(harness.groupRepository.requestedScopes == [.mine] && spy.offerCount == 1)
        #expect(harness.logs(.info).contains { $0.contains("Join for tournament t landed despite") })
        #expect(harness.changes.version == version + 1 && harness.sink.tournaments.count == 1, "the fresh detail handed on")
    }

    @Test func aLostAnswerOnAJoinThatDidNotLandShowsTheFreshDetailAndThePopup() async {
        let spy = SpyPushOptIn()
        let viewModel = await harness.loadedDetailViewModel(.fixture(entryCount: 1), for: destination, pushOptIn: spy)
        harness.repository.actionError = AppError.network

        await viewModel.join()

        #expect(harness.repository.fetchedIDs.count == 2 && harness.presentedError == .network)
        #expect(viewModel.participation == .join && harness.groupRepository.requestedScopes.isEmpty)
        #expect(harness.logs(.warning).contains { $0.contains("Join for tournament t outcome unknown") })
        #expect(harness.logs(.error).contains { $0.contains("Join for tournament \(destination.id) failed") }, "not a refusal")
        #expect(spy.offerCount == 0)
    }

    @Test func aFailedReadBackKeepsTheScreenAndThePopup() async {
        let viewModel = await harness.loadedDetailViewModel(.fixture(entryCount: 1), for: destination)
        harness.repository.actionError = AppError.network
        harness.repository.detailError = AppError.tournamentsUnavailable

        await viewModel.join()

        #expect(harness.presentedError == .network && viewModel.participation == .join)
        #expect(harness.logs(.warning).contains { $0.contains("Could not read back") })
    }

    @Test func aLeaveWhoseAnswerWasLostIsReadBack() async {
        await harness.loadGroups([.tournamentRoomFixture(id: "t")])
        let entered = Tournament.fixture(entryCount: 1, myEntryId: "e1")
        let mine = TournamentEntry.fixture(id: "e1", captainUserId: TestFixtures.user.id)
        let viewModel = await harness.loadedDetailViewModel(entered, entries: [mine], for: destination)
        harness.repository.lostAnswerError = AppError.tournamentActionFailed

        await viewModel.leave()

        #expect(harness.presentedError == nil && viewModel.participation == .join)
        #expect(harness.groupRepository.requestedScopes.count == 2, "Mine reloaded after the leave, as after loadGroups")
        #expect(harness.groups.groups.isEmpty, "the room is dropped")
    }

    @Test func aRemovedEntryWhoseAnswerWasLostIsReadBack() async {
        let organised = Tournament.fixture(entryCount: 2, organizerUserId: TestFixtures.user.id)
        let entries = [TournamentEntry.fixture(id: "e1"), TournamentEntry.fixture(id: "e2")]
        let viewModel = await harness.loadedDetailViewModel(organised, entries: entries, for: destination)
        harness.repository.lostAnswerError = AppError.network

        await viewModel.removeEntry(entries[0])

        #expect(harness.presentedError == nil && viewModel.detail?.entry(id: "e1") == nil)
        #expect(harness.groupRepository.requestedScopes.isEmpty, "a removal moves no room of the caller's")
    }

    /// The detail was stale: the fresh one is shown, so the control agrees with the popup.
    @Test func aRefusalRefetchesTheDetailSoTheControlAndThePopupAgree() async {
        let viewModel = await harness.loadedDetailViewModel(.fixture(maxEntries: 4, entryCount: 3), for: destination)
        harness.repository.actionError = AppError.tournamentFull
        harness.repository.details["t"] = .fixture(tournament: .fixture(maxEntries: 4, entryCount: 4))

        await viewModel.join()

        #expect(harness.repository.fetchedIDs.count == 2 && harness.presentedError == .tournamentFull)
        #expect(viewModel.tournament?.isFull == true)
        #expect(harness.logs(.info).contains { $0.contains("Reading back after tournamentFull") })
    }

    @Test func aTermsRefusalRefetchesNothing() async {
        let viewModel = await harness.loadedDetailViewModel(.fixture(entryCount: 1), for: destination)
        harness.repository.actionError = AppError.termsRequired

        await viewModel.join()

        #expect(harness.repository.fetchedIDs.count == 1 && harness.presentedError == .termsRequired)
        #expect(harness.termsRequiredCount == 1)
    }

    @Test func theTournamentsCapOnAJoinIsAWarningNotAnError() async {
        let viewModel = await harness.loadedDetailViewModel(.fixture(entryCount: 1), for: destination)
        harness.repository.actionError = AppError.tournamentMembershipLimit

        await viewModel.join()

        #expect(harness.presentedError == .tournamentMembershipLimit)
        #expect(harness.logs(.warning).contains { $0.contains("Join for tournament \(destination.id) failed") })
        #expect(harness.logs(.error).isEmpty)
        #expect(harness.repository.joins.count == 1 && harness.repository.fetchedIDs.count == 2, "a refusal refetches the detail")
    }

    /// The sheet closes on the write's answer, not on the refetch: a landed create whose refetch failed is still done.
    @Test func createTeamAnswersTrueWhenTheWriteLandedEvenIfTheRefetchFailed() async {
        let viewModel = await harness.loadedDetailViewModel(.fixture(teamSize: 2, entryCount: 1), for: destination)
        harness.repository.detailError = AppError.network

        let created = await viewModel.createTeam(named: "The Nets")

        #expect(created && harness.presentedError == nil)
        #expect(harness.repository.joins.map(\.teamName) == ["The Nets"])
    }

    /// The sheet is told before the system prompt: `onEntered` runs ahead of the reminders offer, even when the refetch
    /// failed and the sheet cannot close on the entry showing up.
    @Test func createTeamTellsTheSheetBeforeTheRemindersAreOffered() async {
        let spy = SpyPushOptIn()
        let viewModel = await harness.loadedDetailViewModel(.fixture(teamSize: 2, entryCount: 1),
                                                            for: destination,
                                                            pushOptIn: spy)
        harness.repository.detailError = AppError.network
        var order: [String] = []
        spy.onOffer = { order.append("offer") }

        let created = await viewModel.createTeam(named: "The Nets") { order.append("entered") }

        #expect(created && order == ["entered", "offer"])
    }

    @Test func createTeamAnswersFalseOnARefusal() async {
        let viewModel = await harness.loadedDetailViewModel(.fixture(teamSize: 2, entryCount: 1), for: destination)
        harness.repository.actionError = AppError.registrationClosed

        let created = await viewModel.createTeam(named: "The Nets")

        #expect(!created && harness.presentedError == .registrationClosed)
    }
}
