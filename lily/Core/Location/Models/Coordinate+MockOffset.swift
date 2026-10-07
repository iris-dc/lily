import Foundation

nonisolated extension Coordinate {
    /// A fixture spot: `offset` is a fraction of `AppConfig.Location.fixtureSpreadDegrees` from the demo centre, so
    /// every mock (events, groups, tournaments) scatters its places over the same neighbourhood.
    static func aroundMockCenter(lat: Double, lon: Double) -> Coordinate {
        let center = AppConfig.Location.mockCenter
        let spread = AppConfig.Location.fixtureSpreadDegrees
        return Coordinate(latitude: center.latitude + lat * spread, longitude: center.longitude + lon * spread)
    }
}
