import Foundation
import Testing
@testable import lily

/// The create form's place lookups: biased to the draft's spot or the user's position, and a geocoder that could not
/// be asked kept apart from a name nothing answers to.
@MainActor
struct CreateEventPlaceTests {
    private let gdansk = Coordinate(latitude: 54.352, longitude: 18.6466)

    /// The suggestions pass straight through, favouring the draft's spot, else the position `prepare()` read.
    @Test func suggestionsAreBiasedToTheDraftsSpotElseThePosition() async {
        let harness = CreateEventHarness(locationService: MockLocationService(coordinate: gdansk))
        let warsaw = PlaceSuggestion(title: "Warsaw", subtitle: "Poland", coordinate: .init(latitude: 52.23, longitude: 21.01))
        harness.geocoder.suggestionsResult = [warsaw]
        await harness.viewModel.prepare()

        #expect(await harness.viewModel.placeSuggestions(for: "War") == [warsaw])
        harness.viewModel.draft.pickSpot(AppConfig.Location.mockCenter)
        _ = await harness.viewModel.placeSuggestions(for: "Wars")
        harness.viewModel.draft.coordinate = nil
        _ = await harness.viewModel.placeSuggestions(for: "Warsa")

        #expect(harness.geocoder.suggestionQueries == ["War", "Wars", "Warsa"])
        #expect(harness.geocoder.suggestionBiases == [gdansk, AppConfig.Location.mockCenter, gdansk])
    }

    /// A spot cleared after the proposal is geocoded from the name near where the user stands.
    @Test func aClearedSpotIsGeocodedNearThePosition() async {
        let harness = CreateEventHarness(locationService: MockLocationService(coordinate: gdansk))
        await harness.viewModel.prepare()
        harness.viewModel.draft.fillRequired(coordinate: nil)
        harness.geocoder.coordinateResult = gdansk

        await harness.viewModel.submit()

        #expect(harness.geocoder.geocodedBiases == [gdansk])
        #expect(harness.repository.createdDrafts.first?.coordinate == gdansk)
    }

    /// Offline, a name with no spot is a network failure, never "Couldn't find this place"; nothing is sent and the
    /// draft stays for another try.
    @Test func aGeocoderThatCouldNotBeAskedReportsANetworkFailure() async {
        let harness = CreateEventHarness(locationService: MockLocationService(coordinate: nil))
        harness.viewModel.draft.fillRequired(coordinate: nil)
        harness.geocoder.coordinateError = AppError.network

        await harness.viewModel.submit()

        #expect(harness.errorCenter.current?.error == .network)
        #expect(harness.repository.createdDrafts.isEmpty && harness.viewModel.canSubmit)
    }

    /// A dismissed sheet cancels the lookup; nothing reaches the popup.
    @Test func aCancelledLookupStaysQuiet() async {
        let harness = CreateEventHarness(locationService: MockLocationService(coordinate: nil))
        harness.viewModel.draft.fillRequired(coordinate: nil)
        harness.geocoder.coordinateError = CancellationError()

        await harness.viewModel.submit()

        #expect(harness.errorCenter.current == nil && harness.repository.createdDrafts.isEmpty)
    }
}
