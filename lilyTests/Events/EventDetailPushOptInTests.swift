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

    @Test func aJoinWhoseOutcomeIsUnknownAndDidNotLandNeverOffersReminders() async {
        let harness = makeHarness()
        harness.repository.participationError = AppError.network

        await harness.viewModel.join()

        #expect(harness.errorCenter.current?.error == .network)
        #expect(harness.repository.fetchedEventIDs == [harness.viewModel.event.id])
        #expect(spy.offerCount == 0)
    }
}
