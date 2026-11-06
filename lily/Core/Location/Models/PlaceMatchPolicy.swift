import Foundation

/// Which geocoded match may stand for a typed place: a city or an address anywhere, a point of interest only within
/// half the search region of the bias. MapKit's region is a hint, so without this a generic venue name ("Sportplatz")
/// could move a game to another country unseen.
nonisolated enum PlaceMatchPolicy {
    /// `distanceMeters` is from the bias, `nil` when the lookup had none.
    static func isUsable(isPointOfInterest: Bool, distanceMeters: Double?) -> Bool {
        guard isPointOfInterest, let distanceMeters else { return true }
        return distanceMeters <= AppConfig.Events.placeSearchRegionMeters / 2
    }
}
