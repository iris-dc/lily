import Foundation

/// Turns a typed place into a spot and a pinned spot into a name, so the event form needs only one of the two. A
/// `bias` favours places around it (the draft's spot or the user's position) without excluding the rest, so a venue
/// name resolves nearby while a city name still lands on the city.
protocol GeocodingService {
    /// The spot the typed place names ("Gdansk" to its coordinates), or `nil` when nothing answers to it. Throws
    /// `AppError.network` when the geocoder could not be asked (offline, throttled, a server failure), so a name that
    /// was never looked up is never called unknown; a cancelled caller gets `CancellationError`.
    func coordinate(for name: String, near bias: Coordinate?) async throws -> Coordinate?
    /// What the place around the spot is called, or `nil` when nothing is known there.
    func placeName(for coordinate: Coordinate) async -> String?
    /// Places answering to a partial query, best first, distinct by id, at most
    /// `AppConfig.Events.placeSuggestionCount`; empty when nothing does or the geocoder could not be asked.
    func suggestions(for query: String, near bias: Coordinate?) async -> [PlaceSuggestion]
}
