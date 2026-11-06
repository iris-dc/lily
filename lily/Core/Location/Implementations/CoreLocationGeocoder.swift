import MapKit

/// Apple's geocoder through MapKit's requests (the `CLGeocoder` routes are deprecated on iOS 26). One request per
/// call: the form never sends two at once. Results are logged by outcome only, never by text: a place name is the
/// user's content; a failure logs its error domain and code.
final class CoreLocationGeocoder: GeocodingService {
    private let logger: any Logging

    init(logger: any Logging) {
        self.logger = logger
    }

    func coordinate(for name: String, near bias: Coordinate?) async throws -> Coordinate? {
        guard let request = MKGeocodingRequest(addressString: name) else {
            logger.debug(.location, "The typed place resolved to no spot")
            return nil
        }
        if let bias { request.region = Self.region(around: bias) }
        let item: MKMapItem?
        do {
            item = try await request.mapItems.first { Self.isUsable($0, near: bias) }
        } catch {
            try rethrowFailure(error)
            item = nil
        }
        guard let item else {
            logger.debug(.location, "The typed place resolved to no spot")
            return nil
        }
        logger.debug(.location, "The typed place resolved to a spot")
        return Coordinate(item.location.coordinate)
    }

    func suggestions(for query: String, near bias: Coordinate?) async -> [PlaceSuggestion] {
        guard let trimmed = query.nonBlankTrimmed else { return [] }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.address, .pointOfInterest]
        if let bias { request.region = Self.region(around: bias) }
        guard let items = try? await MKLocalSearch(request: request).start().mapItems else {
            logger.debug(.location, "The place query suggested nothing")
            return []
        }
        var seen = Set<PlaceSuggestion.ID>()
        let distinct = items.compactMap(Self.suggestion(from:)).filter { seen.insert($0.id).inserted }
        let suggestions = Array(distinct.prefix(AppConfig.Events.placeSuggestionCount))
        logger.debug(.location, "The place query suggested \(suggestions.count) places")
        return suggestions
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

    /// Returns for "nothing answers"; throws `CancellationError` for a cancelled caller and `AppError.network` when the
    /// geocoder could not be asked, so the form never tells a host offline that their place does not exist.
    private func rethrowFailure(_ error: any Error) throws {
        if AppError.isCancellation(error) { throw CancellationError() }
        guard Self.isFailure(error) else { return }
        let nsError = error as NSError
        logger.warning(.location, "The geocoder could not be asked (\(nsError.domain) \(nsError.code))")
        throw AppError.network
    }

    /// Offline, throttled or a server failure, as opposed to MapKit finding no place for the text.
    private static func isFailure(_ error: any Error) -> Bool {
        if let mapKit = error as? MKError { return mapKit.code != .placemarkNotFound }
        if let location = error as? CLError { return location.code == .network }
        return error is URLError
    }

    /// The region is only a hint to MapKit, so a venue's name can still come back from another country: a point of
    /// interest far outside the region is skipped, while a city or an address anywhere is kept ("Warsaw" lands in Warsaw).
    private static func isUsable(_ item: MKMapItem, near bias: Coordinate?) -> Bool {
        PlaceMatchPolicy.isUsable(isPointOfInterest: item.pointOfInterestCategory != nil,
                                  distanceMeters: bias.map { Coordinate(item.location.coordinate).distance(to: $0) })
    }

    private static func region(around bias: Coordinate) -> MKCoordinateRegion {
        let side = AppConfig.Events.placeSearchRegionMeters
        return MKCoordinateRegion(center: bias.clCoordinate, latitudinalMeters: side, longitudinalMeters: side)
    }

    private static func suggestion(from item: MKMapItem) -> PlaceSuggestion? {
        guard let name = item.name?.nonBlankTrimmed else { return nil }
        return PlaceSuggestion(title: name,
                               subtitle: item.address?.shortAddress.nonBlankTrimmed,
                               coordinate: Coordinate(item.location.coordinate))
    }
}
