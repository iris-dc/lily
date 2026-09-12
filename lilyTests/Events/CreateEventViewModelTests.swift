import Foundation
import Testing
@testable import lily

@MainActor
struct CreateEventViewModelTests {
    /// 08:25:07 UTC, so "the next full hour" is unambiguous.
    /// `nonisolated`: read by a default argument and by `@Test(arguments:)` off the main actor.
    nonisolated private static let now = Date(timeIntervalSince1970: 1_800_000_000 + 25 * 60 + 7)
    nonisolated private static let secondsPerHour: TimeInterval = 3600
    /// Failures with copy of their own and without; both reach the popup as they are.
    nonisolated private static let failures: [AppError] = [.eventCreationFailed, .network]

    /// What the view model handed on through `onCreated`.
    @MainActor private final class CreatedEvents {
        private(set) var events: [SportEvent] = []

        func record(_ event: SportEvent) {
            events.append(event)
        }
    }

    /// Builds a view model over fakes with a fixed clock; `created` records what it handed on. Collaborators not
    /// given are created in the body: a main-actor default argument would be evaluated off the actor.
    @MainActor private final class Harness {
        let repository = FakeEventRepository()
        /// The caller is the user the fake makes host of every created game.
        let identity = FakeIdentityProvider()
        let logger = SpyLogger()
        let errorCenter: ErrorCenter
        let viewModel: CreateEventViewModel
        private let createdEvents = CreatedEvents()

        var created: [SportEvent] { createdEvents.events }

        init(locationService: (any LocationService)? = nil) {
            errorCenter = ErrorCenter(logger: logger)
            viewModel = CreateEventViewModel(repository: repository,
                                             identity: identity,
                                             locationService: locationService ?? MockLocationService(),
                                             errorCenter: errorCenter,
                                             logger: logger,
                                             now: { CreateEventViewModelTests.now },
                                             onCreated: createdEvents.record)
            identity.currentUserID = repository.hostUserID
        }

        /// Fills in what a valid draft needs beyond the defaults.
        func completeDraft() {
            viewModel.draft.title = "Thursday five-a-side"
            viewModel.draft.locationName = "Test Park"
            viewModel.draft.coordinate = AppConfig.Location.mockCenter
        }
    }

    /// A fresh draft proposes tomorrow, on the hour, so the picker starts somewhere sensible.
    @Test func aNewDraftStartsOnTheNextFullHourAtLeastADayAhead() {
        let harness = Harness()
        let startsAt = harness.viewModel.draft.startsAt
        let earliest = Self.now.addingTimeInterval(AppConfig.Events.Creation.defaultStartOffset)

        #expect(startsAt >= earliest)
        #expect(startsAt < earliest.addingTimeInterval(Self.secondsPerHour))
        let components = Calendar.current.dateComponents([.minute, .second], from: startsAt)
        #expect(components.minute == 0 && components.second == 0)
        #expect(harness.viewModel.issues == [.titleMissing, .locationNameMissing, .coordinateMissing])
        #expect(!harness.viewModel.canSubmit)
    }

    @Test func prepareTakesTheSpotFromTheLocationService() async {
        let harness = Harness(locationService: MockLocationService(coordinate: AppConfig.Location.mockCenter))

        await harness.viewModel.prepare()

        #expect(harness.viewModel.draft.coordinate == AppConfig.Location.mockCenter)
        #expect(!harness.viewModel.issues.contains(.coordinateMissing))
        #expect(harness.logger.messages(in: .location, at: .debug).count == 1)
    }

    @Test func prepareKeepsASpotAlreadyChosen() async {
        let service = FakeLocationService()
        service.result = AppConfig.Location.mockCenter
        let harness = Harness(locationService: service)
        let chosen = Coordinate(latitude: 48.8566, longitude: 2.3522)
        harness.viewModel.draft.coordinate = chosen

        await harness.viewModel.prepare()

        #expect(harness.viewModel.draft.coordinate == chosen)
        #expect(service.callCount == 0)
    }

    /// No fix (denied, timed out): the form asks for the spot on the map instead of blocking.
    @Test func prepareWithoutAPositionLeavesTheSpotToTheMap() async {
        let harness = Harness(locationService: MockLocationService(coordinate: nil))

        await harness.viewModel.prepare()

        #expect(harness.viewModel.draft.coordinate == nil)
        #expect(harness.viewModel.issues.contains(.coordinateMissing))
        #expect(harness.logger.messages(in: .location, at: .debug).count == 1)
    }

    @Test func canSubmitFollowsTheIssues() {
        let harness = Harness()
        #expect(!harness.viewModel.canSubmit)

        harness.completeDraft()
        #expect(harness.viewModel.issues.isEmpty)
        #expect(harness.viewModel.canSubmit)

        harness.viewModel.draft.title = "   "
        #expect(harness.viewModel.issues == [.titleMissing])
        #expect(!harness.viewModel.canSubmit)
    }

    @Test func submitCreatesTheEventAndHandsItOn() async throws {
        let harness = Harness()
        harness.completeDraft()

        await harness.viewModel.submit()

        let created = try #require(harness.viewModel.createdEvent)
        #expect(created.id == harness.viewModel.draft.clientId)
        #expect(created.title == "Thursday five-a-side")
        #expect(created.participates && created.participantCount == 1)
        #expect(created.hostUserId == harness.repository.hostUserID)
        #expect(harness.created == [created])
        #expect(harness.repository.createdDrafts == [harness.viewModel.draft])
        #expect(!harness.viewModel.isSubmitting)
        #expect(harness.errorCenter.current == nil)
        let creationLines = harness.logger.messages(in: .events, at: .info).filter { $0.contains("Event created") }
        #expect(creationLines.contains { $0.contains(created.id) && $0.contains("\(created.capacity) spots") })
    }

    @Test func submitIsIgnoredWhileTheDraftHasIssues() async {
        let harness = Harness()

        await harness.viewModel.submit()

        #expect(harness.repository.createdDrafts.isEmpty)
        #expect(harness.viewModel.createdEvent == nil)
        #expect(harness.created.isEmpty)
        #expect(harness.errorCenter.current == nil)
    }

    /// The outcome is unknown, so the backend is asked whether it has the game; when it does not, the popup says what
    /// went wrong, the log marks it as a fault, and the form stays open for another go.
    @Test(arguments: failures)
    func aFailureIsReportedAndLoggedAsAnError(error: AppError) async {
        let harness = Harness()
        harness.completeDraft()
        harness.repository.createError = error

        await harness.viewModel.submit()

        #expect(harness.viewModel.createdEvent == nil)
        #expect(harness.created.isEmpty)
        #expect(harness.repository.fetchedEventIDs == [harness.viewModel.draft.clientId])
        #expect(harness.errorCenter.current?.error == error)
        #expect(harness.logger.messages(in: .events, at: .error).contains { $0.contains("Create failed") })
        #expect(!harness.viewModel.isSubmitting)
        #expect(harness.viewModel.canSubmit)
    }

    /// The backend commits before it answers, so a lost answer may hide a game that exists. It is looked up under the
    /// draft's id, and when the caller hosts it the create counts as done: the list gets the game and nothing is shown.
    @Test(arguments: failures)
    func aCreateThatLandedDespiteAFailureIsAccepted(error: AppError) async {
        let harness = Harness()
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
        let harness = Harness()
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
        let harness = Harness()
        harness.completeDraft()
        harness.repository.createError = AppError.eventCreationFailed
        harness.repository.thrownError = AppError.eventsUnavailable

        await harness.viewModel.submit()

        #expect(harness.viewModel.createdEvent == nil)
        #expect(harness.repository.fetchedEventIDs == [harness.viewModel.draft.clientId])
        #expect(harness.errorCenter.current?.error == .eventCreationFailed)
        #expect(harness.logger.messages(in: .events, at: .warning).contains { $0.contains("Could not check") })
    }

    /// The id is chosen once per draft: a retry sends the same one, so the backend answers the game it may already
    /// have made instead of making a second one.
    @Test func aRetryAfterAFailureSendsTheSameClientId() async {
        let harness = Harness()
        harness.completeDraft()
        harness.repository.createError = AppError.network
        await harness.viewModel.submit()
        harness.repository.createError = nil

        await harness.viewModel.submit()

        let clientId = harness.viewModel.draft.clientId
        #expect(harness.repository.createdDrafts.map(\.clientId) == [clientId, clientId])
        #expect(harness.viewModel.createdEvent != nil)
    }

    @Test func cancellationIsQuiet() async {
        for cancellation: any Error in [CancellationError(), URLError(.cancelled)] {
            let harness = Harness()
            harness.completeDraft()
            harness.repository.createError = cancellation

            await harness.viewModel.submit()

            #expect(harness.viewModel.createdEvent == nil)
            #expect(harness.created.isEmpty)
            #expect(harness.repository.fetchedEventIDs.isEmpty)
            #expect(harness.errorCenter.current == nil)
            #expect(harness.logger.messages(in: .events, at: .error).isEmpty)
            #expect(!harness.viewModel.isSubmitting)
        }
    }

    @Test func aSecondSubmitWhileTheFirstIsInFlightIsDropped() async {
        let harness = Harness()
        harness.completeDraft()
        harness.repository.holdsRequests = true

        let first = Task { await harness.viewModel.submit() }
        await settle(until: { harness.viewModel.isSubmitting })
        #expect(!harness.viewModel.canSubmit)
        await harness.viewModel.submit()
        #expect(harness.repository.createdDrafts.count == 1)

        harness.repository.releaseRequests()
        await first.value
        #expect(harness.viewModel.createdEvent != nil)
        #expect(harness.created.count == 1)
        #expect(!harness.viewModel.isSubmitting)
    }
}
