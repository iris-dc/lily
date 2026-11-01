import Foundation
import Testing
@testable import lily

/// What a create's failure means: a lost answer is looked up under the client id, a lost race is repeated, a reused id
/// is updated, and only what is left reaches the popup.
@MainActor
struct CreateEventOutcomeTests {
    /// Failures with copy of their own and without; both reach the popup as they are.
    nonisolated private static let failures: [AppError] = [.eventCreationFailed, .network]

    /// The outcome is unknown, so the backend is asked whether it has the game; when it does not, the popup says what
    /// went wrong, the log marks it as a fault, and the form stays open for another go.
    @Test(arguments: failures)
    func aFailureIsReportedAndLoggedAsAnError(error: AppError) async {
        let harness = CreateEventHarness()
        harness.completeDraft()
        harness.repository.createError = error

        await harness.viewModel.submit()

        #expect(harness.viewModel.createdEvent == nil)
        #expect(harness.created.isEmpty)
        #expect(harness.repository.fetchedEventIDs == [harness.viewModel.draft.clientId])
        #expect(harness.errorCenter.current?.error == error)
        let failedLines = harness.logger.messages(in: .events, at: .error)
        #expect(failedLines.filter { $0.hasPrefix("Create failed for event \(harness.viewModel.draft.clientId):") }.count == 1)
        #expect(!harness.viewModel.isSubmitting)
        #expect(harness.viewModel.canSubmit)
    }

    /// The backend commits before it answers, so a lost answer may hide a game that exists. It is looked up under the
    /// draft's id, and when the caller hosts it the create counts as done: the list gets the game and nothing is shown.
    @Test(arguments: failures)
    func aCreateThatLandedDespiteAFailureIsAccepted(error: AppError) async {
        let harness = CreateEventHarness()
        harness.completeDraft()
        let clientId = harness.viewModel.draft.clientId
        let stored = SportEvent.fixture(id: clientId, hostUserId: harness.repository.hostUserID, isJoined: true)
        harness.repository.createError = error
        harness.repository.result = .success([stored])

        await harness.viewModel.submit()

        #expect(harness.viewModel.createdEvent == stored)
        #expect(harness.created == [stored])
        #expect(harness.repository.fetchedEventIDs == [clientId])
        #expect(harness.errorCenter.current == nil)
        let landedLines = harness.logger.messages(in: .events, at: .info).filter { $0.contains("Create landed") }
        #expect(landedLines.contains { $0.contains(clientId) && $0.contains("\(error)") })
        #expect(!harness.viewModel.isSubmitting)
    }

    /// Someone else's game under that id is not ours (the backend would have answered `EVENT_ID_TAKEN`): the failure
    /// stands.
    @Test func aFailureStaysWhenTheStoredGameHasAnotherHost() async {
        let harness = CreateEventHarness()
        harness.completeDraft()
        let theirs = SportEvent.fixture(id: harness.viewModel.draft.clientId, hostUserId: "someone-else")
        harness.repository.createError = AppError.network
        harness.repository.result = .success([theirs])

        await harness.viewModel.submit()

        #expect(harness.viewModel.createdEvent == nil)
        #expect(harness.created.isEmpty)
        #expect(harness.errorCenter.current?.error == .network)
    }

    /// When the lookup fails as well, the user sees the create's failure and the log says the check was not possible.
    @Test func aFailureStaysWhenTheLookupFailsToo() async {
        let harness = CreateEventHarness()
        harness.completeDraft()
        let clientId = harness.viewModel.draft.clientId
        harness.repository.createError = AppError.eventCreationFailed
        harness.repository.thrownError = AppError.eventsUnavailable

        await harness.viewModel.submit()

        #expect(harness.viewModel.createdEvent == nil)
        #expect(harness.repository.fetchedEventIDs == [clientId])
        #expect(harness.errorCenter.current?.error == .eventCreationFailed)
        let checkLines = harness.logger.messages(in: .events, at: .warning)
        #expect(checkLines.filter { $0.contains("Could not check whether event \(clientId) landed") }.count == 1)
    }

    /// Nothing under the draft's id is the check's answer, not its fault, so the miss is logged below warning.
    @Test func aCreateThatDidNotLandIsReportedWithoutAWarning() async {
        let harness = CreateEventHarness()
        harness.completeDraft()
        harness.repository.createError = AppError.network

        await harness.viewModel.submit()

        #expect(harness.repository.fetchedEventIDs == [harness.viewModel.draft.clientId])
        #expect(harness.errorCenter.current?.error == .network)
        #expect(harness.logger.messages(in: .events, at: .warning).isEmpty)
        #expect(harness.logger.messages(in: .events, at: .debug).contains { $0.contains("did not land") })
    }

    /// The id is chosen once per draft: a retry sends the same one, so the backend answers the game it may already
    /// have made instead of making a second one.
    @Test func aRetryAfterAFailureSendsTheSameClientId() async {
        let harness = CreateEventHarness()
        harness.completeDraft()
        harness.repository.createError = AppError.network
        await harness.viewModel.submit()
        harness.repository.createError = nil

        await harness.viewModel.submit()

        let clientId = harness.viewModel.draft.clientId
        #expect(harness.repository.createdDrafts.map(\.clientId) == [clientId, clientId])
        #expect(harness.viewModel.createdEvent != nil)
    }

    /// A create is a write like any other: a `TRY_AGAIN` is repeated once under the same client id, a replay on Laurel.
    @Test func aTryAgainOnTheCreateIsRepeatedOnce() async {
        let harness = CreateEventHarness()
        harness.completeDraft()
        harness.repository.nextCreateError = AppError.tryAgain

        await harness.viewModel.submit()

        #expect(harness.repository.createdDrafts.count == 2 && harness.viewModel.createdEvent != nil)
        #expect(harness.errorCenter.current == nil)
        #expect(harness.logger.count(in: .events, at: .info, mentioning: "lost a race") == 1)
    }

    /// The first tap landed with the earlier details and its answer was lost; the user edited and tapped again: the
    /// draft goes out as an update under the same id and the sheet closes with the latest details, no second game.
    @Test func aReusedIdUpdatesTheGameWithTheLatestDetails() async throws {
        let harness = CreateEventHarness()
        harness.completeDraft()
        let clientId = harness.viewModel.draft.clientId
        harness.repository.result = .success([.fixture(id: clientId, hostUserId: harness.repository.hostUserID, isJoined: true)])
        harness.repository.createError = AppError.createIdReused
        harness.viewModel.draft.title = "Thursday five-a-side, moved"

        await harness.viewModel.submit()

        let created = try #require(harness.viewModel.createdEvent)
        #expect(created.title == "Thursday five-a-side, moved" && harness.viewModel.isDone)
        #expect(harness.repository.updatedDrafts.map(\.id) == [clientId])
        #expect(harness.repository.updatedDrafts.first?.draft == harness.viewModel.draft)
        #expect(harness.repository.fetchedEventIDs.isEmpty, "no lookup")
        #expect(harness.created == [created] && harness.errorCenter.current == nil)
        #expect(harness.logger.count(in: .events, at: .warning, mentioning: clientId, "updating it") == 1)
    }

    /// The update carries no group, so a game whose first tap landed in one group stays there when the repeat named
    /// another: the list shows the backend's group and the log says so.
    @Test func aReusedIdKeepsTheGameInItsFirstGroupAndWarns() async throws {
        let harness = CreateEventHarness()
        harness.completeDraft()
        let clientId = harness.viewModel.draft.clientId
        let first = EventGroupRef(id: "g1", name: "Kickers", visibility: .public, isDeleted: false)
        harness.repository.result = .success([.fixture(id: clientId, hostUserId: harness.repository.hostUserID, group: first)])
        harness.repository.createError = AppError.createIdReused
        harness.viewModel.draft.group = EventGroupRef(id: "g2", name: "Runners", visibility: .public, isDeleted: false)

        await harness.viewModel.submit()

        let created = try #require(harness.viewModel.createdEvent)
        #expect(created.group?.id == "g1" && harness.created == [created] && harness.errorCenter.current == nil)
        #expect(harness.logger.count(in: .events, at: .warning, mentioning: created.id, "stays in group g1", "named g2") == 1)
    }

    @Test func anUpdateRefusedAfterAReusedIdReachesThePopup() async {
        let harness = CreateEventHarness()
        harness.completeDraft()
        harness.repository.createError = AppError.createIdReused
        harness.repository.updateError = AppError.eventUpdateFailed

        await harness.viewModel.submit()

        #expect(harness.viewModel.createdEvent == nil && harness.created.isEmpty)
        #expect(harness.errorCenter.current?.error == .eventUpdateFailed)
        #expect(harness.repository.fetchedEventIDs.isEmpty && harness.viewModel.canSubmit)
    }
}
