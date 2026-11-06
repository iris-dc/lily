import Foundation
import Testing
@testable import lily

/// Place suggestions and the mock geocoder that serves them offline under `-mock-location`.
@MainActor
struct PlaceSuggestionTests {
    private let mock = MockGeocodingService()

    /// Two branches of one chain share a name and a short address; the spot keeps their rows apart.
    @Test func theIdTellsNamesakesApartByTheirSpot() {
        let first = PlaceSuggestion(title: "Decathlon", subtitle: nil, coordinate: .init(latitude: 52.5, longitude: 13.4))
        let second = PlaceSuggestion(title: "Decathlon", subtitle: nil, coordinate: .init(latitude: 52.6, longitude: 13.3))
        #expect(first.id != second.id)
        #expect(first.id == PlaceSuggestion(title: "Decathlon", subtitle: nil, coordinate: first.coordinate).id)
    }

    /// The demo cities a query starts, case-insensitively, each on the spot its name geocodes to.
    @Test func theMockSuggestsTheDemoCitiesTheQueryStarts() async {
        let suggestions = await mock.suggestions(for: " gd ", near: nil)
        let geocoded = await mock.coordinate(for: "Gdansk", near: nil)
        #expect(suggestions.map(\.title) == ["Gdansk"])
        #expect(geocoded != nil && suggestions.first?.coordinate == geocoded)
    }

    /// A query no demo city starts is offered as a place of its own; a blank one asks for nothing.
    @Test func theMockOffersTheQueryItselfAndNothingForBlank() async {
        #expect(await mock.suggestions(for: "Dave's backyard", near: nil).map(\.title) == ["Dave's backyard"])
        #expect(await mock.suggestions(for: "  ", near: nil).isEmpty)
        #expect(await mock.suggestions(for: "M", near: nil).count <= AppConfig.Events.placeSuggestionCount)
    }
}
