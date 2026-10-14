import Foundation
import Testing
@testable import lily

/// The reminder prompt follows a create: once, after the game was handed on, whether the backend answered directly or
/// the create landed although its answer was lost; a failure that stays a failure offers nothing.
@MainActor
struct CreateEventPushOptInTests {
    private let spy = SpyPushOptIn()

    /// The sheet dismisses on `createdEvent` and the list behind has the game before the permission prompt comes up.
    @Test func aCreateOffersRemindersOnceAfterTheGameWasHandedOn() async {
        let harness = CreateEventHarness(pushOptIn: spy)
        harness.completeDraft()
        var handedOnAtOffer = false
        spy.onOffer = { handedOnAtOffer = harness.viewModel.createdEvent != nil && !harness.created.isEmpty }

        await harness.viewModel.submit()

        #expect(spy.offerCount == 1)
        #expect(handedOnAtOffer)
    }

    /// The backend commits before it answers: a game found under the draft's id and hosted by the caller is a create
    /// that landed, and it earns the prompt like a direct answer.
    @Test func aCreateThatLandedDespiteAFailureOffersRemindersOnce() async {
        let harness = CreateEventHarness(pushOptIn: spy)
        harness.completeDraft()
        let clientId = harness.viewModel.draft.clientId
        let stored = SportEvent.fixture(id: clientId, hostUserId: harness.repository.hostUserID, isJoined: true)
        harness.repository.createError = AppError.network
        harness.repository.result = .success([stored])

        await harness.viewModel.submit()

        #expect(harness.viewModel.createdEvent == stored)
        #expect(spy.offerCount == 1)
    }

    /// The lookup fails as well, so the failure stands: the popup is what the user sees, and there is no game to be
    /// reminded of.
    @Test func aCreateThatFailedForGoodNeverOffersReminders() async {
        let harness = CreateEventHarness(pushOptIn: spy)
        harness.completeDraft()
        harness.repository.createError = AppError.eventCreationFailed
        harness.repository.thrownError = AppError.eventsUnavailable

        await harness.viewModel.submit()

        #expect(harness.errorCenter.current?.error == .eventCreationFailed)
        #expect(spy.offerCount == 0)
    }
}
