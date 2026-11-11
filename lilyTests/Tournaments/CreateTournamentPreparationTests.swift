import Foundation
import Testing
@testable import lily

/// What the wizard's pages read from a new tournament's view model beyond the draft: the groups-read-landed flag
/// behind the hosting-group placeholder, and the geocoder seam behind the place page.
@MainActor
struct CreateTournamentPreparationTests {
    private let harness = TournamentHarness()

    /// The wizard's hosting-group page shows a placeholder until the groups read lands.
    @Test func prepareMarksTheGroupsReadLanded() async {
        let viewModel = harness.makeCreateViewModel()
        #expect(!viewModel.hasLoadedGroups)

        await viewModel.prepare()

        #expect(viewModel.hasLoadedGroups)
    }

    /// The wizard's place page asks through the view model: the geocoder's answer, biased to the draft's spot, else
    /// the position prepare read.
    @Test func placeSuggestionsComeFromTheGeocoderBiasedToTheSpot() async {
        let geocoder = FakeGeocodingService()
        geocoder.suggestionsResult = [PlaceSuggestion(title: "Górki Zachodnie",
                                                      subtitle: nil,
                                                      coordinate: AppConfig.Location.mockCenter)]
        let location = MockLocationService(coordinate: AppConfig.Location.mockCenter)
        let viewModel = harness.makeCreateViewModel(locationService: location, geocoder: geocoder)
        await viewModel.prepare()
        let spot = Coordinate(latitude: 54.35, longitude: 18.65)
        viewModel.draft.pickSpot(spot)

        let found = await viewModel.placeSuggestions(for: "Gór")

        #expect(found.map(\.title) == ["Górki Zachodnie"])
        #expect(geocoder.suggestionQueries == ["Gór"] && geocoder.suggestionBiases == [spot])
    }
}
