import Foundation

/// Deterministic geocoding for previews, tests and `-mock-location` runs: every non-blank name lands somewhere fixed in
/// the fixtures' neighbourhood (the same name always on the same spot), and every spot is called after the demo city.
/// The bias is ignored: the spots are fixed already, and the mock never fails.
final class MockGeocodingService: GeocodingService {
    func coordinate(for name: String, near bias: Coordinate?) async -> Coordinate? {
        guard let trimmed = name.nonBlankTrimmed else { return nil }
        let seed = trimmed.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return .aroundMockCenter(lat: Double(seed % 7) / 7 - 0.5, lon: Double(seed % 11) / 11 - 0.5)
    }

    func placeName(for coordinate: Coordinate) async -> String? {
        "Berlin"
    }

    /// The demo cities whose names start with the query, else the query itself as a place of its own, so any typed
    /// name can be picked and always lands on its deterministic spot.
    func suggestions(for query: String, near bias: Coordinate?) async -> [PlaceSuggestion] {
        guard let trimmed = query.nonBlankTrimmed else { return [] }
        let cities = ["Warsaw", "Gdansk", "Berlin", "Hamburg", "Munich", "Prague", "Paris", "Madrid"]
        let matches = cities.filter { $0.lowercased().hasPrefix(trimmed.lowercased()) }
        let titles = matches.isEmpty ? [trimmed] : matches
        var suggestions: [PlaceSuggestion] = []
        for title in titles.prefix(AppConfig.Events.placeSuggestionCount) {
            guard let coordinate = await coordinate(for: title, near: bias) else { continue }
            suggestions.append(PlaceSuggestion(title: title, subtitle: nil, coordinate: coordinate))
        }
        return suggestions
    }
}
