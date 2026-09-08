import Foundation

/// Framework-free coordinate so models and tests never import CoreLocation.
nonisolated struct Coordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    private static let earthRadiusMeters = 6_371_000.0

    /// Great-circle distance in meters (haversine).
    func distance(to other: Coordinate) -> Double {
        let lat1 = latitude * .pi / 180, lat2 = other.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * Self.earthRadiusMeters * asin(min(1, sqrt(a)))
    }
}
