import Foundation
import Testing
@testable import lily

/// The edit form's place: lookups biased to the stored spot, and the place bookkeeping never counting as an edit.
@MainActor
struct EditEventPlaceTests {
    private let repository = FakeEventRepository()
    private let geocoder = FakeGeocodingService()
    private let logger = SpyLogger()
    private let event = SportEvent.fixture(id: "e", startsAt: Date(timeIntervalSince1970: 1_800_003_600), hostUserId: "host")
    private let viewModel: EditEventViewModel

    init() {
        repository.result = .success([event])
        viewModel = EditEventViewModel(event: event,
                                       repository: repository,
                                       geocoder: geocoder,
                                       errorCenter: ErrorCenter(logger: logger),
                                       logger: logger,
                                       tryAgainDelay: .zero,
                                       now: { Date(timeIntervalSince1970: 1_800_000_000) },
                                       currencyCode: EventDraft.testCurrencyCode,
                                       onChange: { _ in })
    }

    /// An edit starts on the stored spot as the host's choice, so a reworded name never moves the game.
    @Test func anEditStartsWithItsSpotPicked() {
        #expect(viewModel.draft.spotPickedOnMap && viewModel.draft.suggestedName == nil)
    }

    /// Suggestions favour the draft's spot, else the game's stored one; a cleared spot is geocoded near it too.
    @Test func lookupsAreBiasedToTheStoredSpot() async {
        let moved = Coordinate(latitude: 54.352, longitude: 18.6466)
        viewModel.draft.pickSpot(moved)
        _ = await viewModel.placeSuggestions(for: "Park")
        viewModel.draft.coordinate = nil
        _ = await viewModel.placeSuggestions(for: "Park")
        #expect(geocoder.suggestionBiases == [moved, event.location.coordinate])

        viewModel.draft.locationName = "Mauerpark"
        geocoder.coordinateResult = moved
        await viewModel.submit()
        #expect(geocoder.geocodedBiases == [event.location.coordinate])
    }

    /// A suggestion picked and then undone by hand leaves the draft as stored but for the bookkeeping: nothing to save.
    @Test func theBookkeepingAloneIsNoChange() {
        let original = viewModel.draft
        let mauerpark = Coordinate(latitude: 52.54, longitude: 13.4)
        viewModel.draft.apply(PlaceSuggestion(title: "Mauerpark", subtitle: nil, coordinate: mauerpark))
        #expect(viewModel.hasChanges)
        viewModel.draft.locationName = original.locationName
        viewModel.draft.coordinate = original.coordinate
        #expect(!viewModel.draft.spotPickedOnMap && viewModel.draft.suggestedName != nil)
        #expect(!viewModel.hasChanges && !viewModel.canSubmit)
    }
}
