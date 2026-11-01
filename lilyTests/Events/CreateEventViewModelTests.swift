import Foundation
import Testing
@testable import lily

@MainActor
struct CreateEventViewModelTests {
    /// `nonisolated`: read by `@Test(arguments:)` off the main actor.
    nonisolated private static let now = CreateEventHarness.now
    nonisolated private static let secondsPerHour: TimeInterval = 3600
    /// A fresh draft proposes tomorrow, on the hour, so the picker starts somewhere sensible.
    @Test func aNewDraftStartsOnTheNextFullHourAtLeastADayAhead() {
        let harness = CreateEventHarness()
        let startsAt = harness.viewModel.draft.startsAt
        let earliest = Self.now.addingTimeInterval(AppConfig.Events.Creation.defaultStartOffset)

        #expect(startsAt >= earliest)
        #expect(startsAt < earliest.addingTimeInterval(Self.secondsPerHour))
        let components = Calendar.current.dateComponents([.minute, .second], from: startsAt)
        #expect(components.minute == 0 && components.second == 0)
        #expect(harness.viewModel.issues == [.titleMissing, .locationNameMissing, .coordinateMissing])
        #expect(!harness.viewModel.canSubmit)
    }

    /// The form's price is typed in the user's currency as it was when the sheet opened; the created game carries it.
    @Test func aNewDraftIsPricedInTheUsersCurrency() async {
        let harness = CreateEventHarness(currencyCode: "PLN")
        harness.completeDraft()
        harness.viewModel.draft.price = 40

        await harness.viewModel.submit()

        #expect(harness.viewModel.draft.currencyCode == "PLN")
        #expect(harness.created.first?.price == Price(amount: 40, currencyCode: "PLN"))
    }

    @Test func prepareTakesTheSpotFromTheLocationService() async {
        let harness = CreateEventHarness(locationService: MockLocationService(coordinate: AppConfig.Location.mockCenter))

        await harness.viewModel.prepare()

        #expect(harness.viewModel.draft.coordinate == AppConfig.Location.mockCenter)
        #expect(!harness.viewModel.issues.contains(.coordinateMissing))
        #expect(harness.logger.messages(in: .location, at: .debug).count == 1)
    }

    @Test func prepareKeepsASpotAlreadyChosen() async {
        let service = FakeLocationService()
        service.result = AppConfig.Location.mockCenter
        let harness = CreateEventHarness(locationService: service)
        let chosen = Coordinate(latitude: 48.8566, longitude: 2.3522)
        harness.viewModel.draft.coordinate = chosen

        await harness.viewModel.prepare()

        #expect(harness.viewModel.draft.coordinate == chosen)
        #expect(service.callCount == 0)
    }

    /// No fix (denied, timed out): the form asks for the spot on the map instead of blocking.
    @Test func prepareWithoutAPositionLeavesTheSpotToTheMap() async {
        let harness = CreateEventHarness(locationService: MockLocationService(coordinate: nil))

        await harness.viewModel.prepare()

        #expect(harness.viewModel.draft.coordinate == nil)
        #expect(harness.viewModel.issues.contains(.coordinateMissing))
        #expect(harness.logger.messages(in: .location, at: .debug).count == 1)
    }

    @Test func canSubmitFollowsTheIssues() {
        let harness = CreateEventHarness()
        #expect(!harness.viewModel.canSubmit)

        harness.completeDraft()
        #expect(harness.viewModel.issues.isEmpty)
        #expect(harness.viewModel.canSubmit)

        harness.viewModel.draft.title = "   "
        #expect(harness.viewModel.issues == [.titleMissing])
        #expect(!harness.viewModel.canSubmit)
    }

    /// "5..5" reads in no locale, so the case holds whatever locale the test host runs in.
    @Test func anUnreadablePriceHoldsCreateUntilItReadsAgain() {
        let harness = CreateEventHarness()
        harness.completeDraft()

        harness.viewModel.draft.priceText = "5..5"
        #expect(!harness.viewModel.canSubmit)
        #expect(harness.viewModel.issues == [.priceUnreadable])

        harness.viewModel.draft.priceText = "5"
        #expect(harness.viewModel.canSubmit)
        #expect(harness.viewModel.draft.price == 5)

        harness.viewModel.draft.priceText = ""
        #expect(harness.viewModel.canSubmit)
        #expect(harness.viewModel.draft.isFree)
    }

    @Test func submitCreatesTheEventAndHandsItOn() async throws {
        let harness = CreateEventHarness()
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
        #expect(creationLines.contains { $0.contains(created.id) && $0.contains(created.spotsDescription) })
    }

    @Test func submitIsIgnoredWhileTheDraftHasIssues() async {
        let harness = CreateEventHarness()

        await harness.viewModel.submit()

        #expect(harness.repository.createdDrafts.isEmpty)
        #expect(harness.viewModel.createdEvent == nil)
        #expect(harness.created.isEmpty)
        #expect(harness.errorCenter.current == nil)
    }

    @Test func cancellationIsQuiet() async {
        for cancellation: any Error in [CancellationError(), URLError(.cancelled)] {
            let harness = CreateEventHarness()
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
        let harness = CreateEventHarness()
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
