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

    /// Type-ahead through MapKit's completer: `MKLocalSearch` on a fragment fuzzy-matches famous names worldwide
    /// regardless of the region ("Gda" answered Jeddah from Gdansk), while the completer matches what is still being
    /// typed around the bias. Completions are resolved to places until `placeSuggestionCount` distinct ones answer,
    /// nearest the bias first; a cancelled ask stops instead of waiting out the completer and the resolves.
    func suggestions(for query: String, near bias: Coordinate?) async -> [PlaceSuggestion] {
        guard let trimmed = query.nonBlankTrimmed else { return [] }
        let completions = await PlaceCompletionSession().completions(for: trimmed, near: bias.map(Self.region(around:)))
        guard !Task.isCancelled else { return [] }
        var seen = Set<PlaceSuggestion.ID>()
        var resolved: [PlaceSuggestion] = []
        for completion in completions where resolved.count < AppConfig.Events.placeSuggestionCount {
            guard !Task.isCancelled else { return [] }
            guard let suggestion = await Self.suggestion(resolving: completion, near: bias),
                  seen.insert(suggestion.id).inserted else { continue }
            resolved.append(suggestion)
        }
        let suggestions = resolved.nearestFirst(to: bias)
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

    /// The place a completion names: the search scoped to the completion answers the full map item, so a picked row
    /// fills the draft's name and spot at once.
    private static func suggestion(resolving completion: MKLocalSearchCompletion,
                                   near bias: Coordinate?) async -> PlaceSuggestion? {
        let request = MKLocalSearch.Request(completion: completion)
        if let bias { request.region = region(around: bias) }
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else { return nil }
        return suggestion(from: item)
    }
}

/// One type-ahead ask of `MKLocalSearchCompleter` (delegate-driven), bridged to async: the delegate's answer, results
/// or a failure, resumes the continuation, and a deadline settles with whatever has arrived so no caller can wait
/// forever on a callback that never comes. One session per ask: a cancelled ask can still be parked on its
/// continuation while the next keystroke's session runs, so the completer is never shared between asks; a late
/// answer is dropped by the field's stale-drop rules.
private final class PlaceCompletionSession: NSObject, @MainActor MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private var continuation: CheckedContinuation<[MKLocalSearchCompletion], Never>?
    private var deadline: Task<Void, Never>?

    func completions(for query: String, near region: MKCoordinateRegion?) async -> [MKLocalSearchCompletion] {
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        if let region { completer.region = region }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            deadline = Task { [weak self] in
                try? await Task.sleep(for: AppConfig.Events.placeSuggestionTimeout)
                guard let self, !Task.isCancelled else { return }
                settle(with: completer.results)
            }
            completer.queryFragment = query
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        settle(with: completer.results)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        settle(with: [])
    }

    private func settle(with results: [MKLocalSearchCompletion]) {
        deadline?.cancel()
        deadline = nil
        continuation?.resume(returning: results)
        continuation = nil
    }
}
