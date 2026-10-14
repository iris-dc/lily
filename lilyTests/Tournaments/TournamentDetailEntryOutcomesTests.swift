import Foundation
import Testing
@testable import lily

/// What the detail does with the refetch that follows an entry write. The write landed on the backend, so a refetch that
/// fails must not leave the stale control on screen, and one that finds nothing means the tournament is gone for the
/// caller.
@MainActor
struct TournamentDetailEntryOutcomesTests {
    private let harness = TournamentHarness()
    private let destination = TournamentDestination(id: "t", name: "Tuesday Table Tennis")

    /// The popup belongs to the write that landed. The recorded change makes the view's keyed task ask again and the
    /// lists behind reload; that reload repairs the screen.
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

    /// An entrant who lost the hosting group's membership, or an operator delete: the screen dismisses, the room leaves
    /// Mine and the lists behind reload.
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

    /// A lost connection on the write is reported as it is: unlike a game's join, the entry is not looked up afterwards,
    /// so nothing is fetched, no room moves, no change is recorded and no reminder is offered.
    @Test func aNetworkFailureOnAnEntryWriteIsNotSecondGuessed() async {
        let spy = SpyPushOptIn()
        let viewModel = await harness.loadedDetailViewModel(.fixture(entryCount: 1), for: destination, pushOptIn: spy)
        harness.repository.actionError = AppError.network
        let version = harness.changes.version

        await viewModel.join()

        #expect(harness.repository.joins.count == 1 && harness.repository.fetchedIDs.count == 1, "no refetch")
        #expect(harness.presentedError == .network)
        #expect(harness.logs(.error).contains { $0.contains("Join for tournament \(destination.id) failed") }, "not a refusal")
        #expect(harness.changes.version == version && harness.groupRepository.requestedScopes.isEmpty)
        #expect(spy.offerCount == 0)
    }
}
