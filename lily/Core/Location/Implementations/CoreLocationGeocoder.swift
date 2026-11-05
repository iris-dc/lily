import MapKit

/// Apple's geocoder through MapKit's requests (the `CLGeocoder` routes are deprecated on iOS 26). One request per
/// call: the form never sends two at once. Results are logged by outcome only, never by text: a place name is the
/// user's content.
final class CoreLocationGeocoder: GeocodingService {
    private let logger: any Logging

    init(logger: any Logging) {
        self.logger = logger
    }

    func coordinate(for name: String) async -> Coordinate? {
        guard let request = MKGeocodingRequest(addressString: name),
              let item = try? await request.mapItems.first else {
            logger.debug(.location, "The typed place resolved to no spot")
            return nil
        }
        logger.debug(.location, "The typed place resolved to a spot")
        return Coordinate(item.location.coordinate)
    }

    func placeName(for coordinate: Coordinate) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location),
              let name = (try? await request.mapItems.first?.name)?.nonBlankTrimmed else {
            logger.debug(.location, "The spot resolved to no place name")
            return nil
        }
        logger.debug(.location, "The spot resolved to a place name")
        return name
    }
}
