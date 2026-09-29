import MapKit

/// Where the events map opens: on the user, at the filter's radius, whatever the pins. Pure, so the choice is tested.
nonisolated enum MapFraming {
    /// The user's surroundings at `radiusMeters` (the default filter radius when the filter has none), padded by
    /// `DesignTokens.Layout.mapRegionPadding`; `nil` while the position is unknown, in which case the map frames its
    /// content instead.
    static func initialRegion(userLocation: Coordinate?, radiusMeters: Double?) -> MKCoordinateRegion? {
        guard let userLocation else { return nil }
        let diameter = 2 * (radiusMeters ?? AppConfig.Events.defaultFilterRadiusMeters) * DesignTokens.Layout.mapRegionPadding
        return MKCoordinateRegion(center: userLocation.clCoordinate, latitudinalMeters: diameter, longitudinalMeters: diameter)
    }
}
