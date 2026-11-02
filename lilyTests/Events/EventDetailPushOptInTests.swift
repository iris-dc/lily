import Foundation
import Testing
@testable import lily

/// Only a join that landed earns the reminder prompt, once, after the control is released.
@MainActor
struct EventDetailPushOptInTests {
    private let spy = SpyPushOptIn()

    private func makeHarness(participants: Int = 1, isJoined: Bool = false) -> EventDetailHarness {
        EventDetailHarness(event: .fixture(capacity: 4, participants: participants, hostUserId: "host", isJoined: isJoined),
                           pushOptIn: spy)
    }

    /// The control is done before the permission prompt comes up, so it never spins behind the alert.
    @Test func aSuccessfulJoinOffersRemindersOnceAfterTheControlIsReleased() async {
        let harness = makeHarness()
        var busyAtOffer: Bool?
        spy.onOffer = { busyAtOffer = harness.viewModel.isBusy }

        await harness.viewModel.join()

        #expect(spy.offerCount == 1)
        #expect(busyAtOffer == false)
    }

    /// A Leave tapped while the prompt is up owns the control to its own end: the join released its guard before the
    /// offer, so nothing clears the leave's flag early, and a second tap during it is dropped.
    @Test func aLeaveStartedDuringTheReminderOfferKeepsItsGuardUntilItLands() async {
        let harness = makeHarness()
        spy.holdsRequests = true
        let join = Task { await harness.viewModel.join() }
        await settle(until: { spy.isHolding })
        #expect(!harness.viewModel.isBusy, "the control is free while the prompt is up")

        harness.repository.holdsRequests = true
        let leave = Task { await harness.viewModel.leave() }
        await settle(until: { harness.viewModel.isBusy })
        spy.releaseRequests()
        await join.value
        #expect(harness.viewModel.isBusy, "the join's return leaves the leave's guard alone")
        await harness.viewModel.leave()
        #expect(harness.repository.leftEventIDs.count == 1, "a second leave during the first is dropped")

        harness.repository.releaseRequests()
        await leave.value
        #expect(!harness.viewModel.isBusy && harness.repository.leftEventIDs == [harness.viewModel.event.id])
        #expect(spy.offerCount == 1)
    }

    @Test func aLeaveNeverOffersReminders() async {
        let harness = makeHarness(participants: 2, isJoined: true)

        await harness.viewModel.leave()

        #expect(harness.replaced.count == 1)
        #expect(spy.offerCount == 0)
    }

    @Test func aRefusedJoinNeverOffersReminders() async {
        let harness = makeHarness()
        harness.repository.participationError = AppError.eventFull

        await harness.viewModel.join()

        #expect(harness.errorCenter.current?.error == .eventFull)
        #expect(spy.offerCount == 0)
    }

    /// The read-back shows the caller in: the join landed, and it earns the prompt as a direct answer does.
    @Test func aJoinWhoseOutcomeIsUnknownButLandedOffersRemindersOnce() async {
        let harness = makeHarness()
        harness.repository.result = .success([harness.viewModel.event.updatingParticipation(count: 2, isJoined: true)])
        harness.repository.participationError = AppError.network

        await harness.viewModel.join()

        #expect(harness.errorCenter.current == nil)
        #expect(spy.offerCount == 1)
    }

    @Test func aJoinWhoseOutcomeIsUnknownAndDidNotLandNeverOffersReminders() async {
        let harness = makeHarness()
        harness.repository.participationError = AppError.network

        await harness.viewModel.join()

        #expect(harness.errorCenter.current?.error == .network)
        #expect(harness.repository.fetchedEventIDs == [harness.viewModel.event.id])
        #expect(spy.offerCount == 0)
    }
}
