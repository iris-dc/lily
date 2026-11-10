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
        #expect(harness.viewModel.issues == [.titleMissing, .placeMissing])
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

    /// The wizard's hosting-group page shows a placeholder until the groups read lands; prepare marks it.
    @Test func prepareMarksTheGroupsReadAsLanded() async {
        let harness = CreateEventHarness()
        #expect(!harness.viewModel.hasLoadedGroups)

        await harness.viewModel.prepare()

        #expect(harness.viewModel.hasLoadedGroups)
    }

    @Test func prepareTakesTheSpotFromTheLocationService() async {
        let harness = CreateEventHarness(locationService: MockLocationService(coordinate: AppConfig.Location.mockCenter))

        await harness.viewModel.prepare()

        #expect(harness.viewModel.draft.coordinate == AppConfig.Location.mockCenter)
        #expect(!harness.viewModel.issues.contains(.placeMissing))
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
        #expect(harness.viewModel.issues.contains(.placeMissing))
        #expect(harness.logger.messages(in: .location, at: .debug).count == 1)
    }

    /// Only a name typed: the spot is geocoded from it on submit, so the game lands where the name says ("Gdansk" shows
    /// to people around Gdansk) and the sent draft carries it.
    @Test func aNameAloneIsGeocodedIntoTheSpotOnSubmit() async throws {
        let harness = CreateEventHarness(locationService: MockLocationService(coordinate: nil))
        harness.completeDraft()
        harness.viewModel.draft.coordinate = nil
        let gdansk = Coordinate(latitude: 54.352, longitude: 18.6466)
        harness.geocoder.coordinateResult = gdansk

        await harness.viewModel.submit()

        #expect(harness.geocoder.geocodedNames == [harness.viewModel.draft.trimmedLocationName])
        #expect(harness.viewModel.draft.coordinate == gdansk, "the resolved spot stays on the draft")
        let sent = try #require(harness.repository.createdDrafts.first)
        #expect(sent.coordinate == gdansk)
        #expect(harness.created.count == 1 && harness.errorCenter.current == nil)
    }

    /// A name the geocoder cannot place: the popup says so, nothing is sent, the draft stays for a correction.
    @Test func aNameTheGeocoderCannotPlaceIsRefusedBeforeTheSend() async {
        let harness = CreateEventHarness(locationService: MockLocationService(coordinate: nil))
        harness.completeDraft()
        harness.viewModel.draft.coordinate = nil
        harness.geocoder.coordinateResult = nil

        await harness.viewModel.submit()

        #expect(harness.errorCenter.current?.error == .placeNotFound)
        #expect(harness.repository.createdDrafts.isEmpty && harness.created.isEmpty)
        #expect(harness.viewModel.createdEvent == nil && !harness.viewModel.isSubmitting)
        #expect(harness.viewModel.canSubmit, "the draft stays for a correction")
    }

    /// The GPS proposal is not the host's word: a typed name moves it on submit, so the game lands where the name
    /// says; a spot picked on the map stays whatever is typed.
    @Test func aTypedNameMovesTheProposedSpotButNeverAPickedOne() async throws {
        let harness = CreateEventHarness()
        harness.completeDraft()
        harness.viewModel.draft.spotPickedOnMap = false
        let gdansk = Coordinate(latitude: 54.352, longitude: 18.6466)
        harness.geocoder.coordinateResult = gdansk

        await harness.viewModel.submit()

        let sent = try #require(harness.repository.createdDrafts.first)
        #expect(sent.coordinate == gdansk && harness.geocoder.geocodedNames == ["Test Park"])

        let picked = CreateEventHarness()
        picked.completeDraft()
        picked.geocoder.coordinateResult = gdansk

        await picked.viewModel.submit()

        let kept = try #require(picked.repository.createdDrafts.first)
        #expect(kept.coordinate == AppConfig.Location.mockCenter && picked.geocoder.geocodedNames.isEmpty)
    }

    /// Only a spot picked: the place is named after it on submit; a name the geocoder does not know falls back to the
    /// coordinates as the map row shows them, so the payload never goes out blank.
    @Test func aSpotAloneGetsItsNameFromTheGeocoderOnSubmit() async throws {
        let harness = CreateEventHarness()
        harness.completeDraft()
        harness.viewModel.draft.locationName = ""
        let spot = AppConfig.Location.mockCenter
        harness.viewModel.draft.coordinate = spot
        harness.geocoder.nameResult = "Mauerpark"

        await harness.viewModel.submit()

        #expect(harness.geocoder.reversedCoordinates == [spot])
        let sent = try #require(harness.repository.createdDrafts.first)
        #expect(sent.trimmedLocationName == "Mauerpark")

        let bare = CreateEventHarness()
        bare.completeDraft()
        bare.viewModel.draft.locationName = " "
        bare.viewModel.draft.coordinate = spot
        bare.geocoder.nameResult = nil

        await bare.viewModel.submit()

        let fallback = try #require(bare.repository.createdDrafts.first)
        #expect(fallback.trimmedLocationName == AppBranding.Events.Create.coordinateText(spot), "never blank on the wire")
        #expect(bare.errorCenter.current == nil)
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
