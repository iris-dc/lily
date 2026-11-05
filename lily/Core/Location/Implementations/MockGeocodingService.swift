import Foundation

/// Deterministic geocoding for previews, tests and `-mock-location` runs: every non-blank name lands somewhere fixed in
/// the fixtures' neighbourhood (the same name always on the same spot), and every spot is called after the demo city.
final class MockGeocodingService: GeocodingService {
    func coordinate(for name: String) async -> Coordinate? {
        guard let trimmed = name.nonBlankTrimmed else { return nil }
        let seed = trimmed.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return .aroundMockCenter(lat: Double(seed % 7) / 7 - 0.5, lon: Double(seed % 11) / 11 - 0.5)
    }

    func placeName(for coordinate: Coordinate) async -> String? {
        "Berlin"
    }
}
