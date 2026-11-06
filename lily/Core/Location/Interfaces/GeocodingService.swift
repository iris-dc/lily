import Foundation

/// Turns a typed place into a spot and a pinned spot into a name, so the event form needs only one of the two.
/// Failures answer `nil`, never throw: the caller decides what a missing half means.
protocol GeocodingService {
    /// The spot the typed place names ("Gdansk" to its coordinates), or `nil` when nothing answers to it.
    func coordinate(for name: String) async -> Coordinate?
    /// What the place around the spot is called, or `nil` when nothing is known there.
    func placeName(for coordinate: Coordinate) async -> String?
    /// Places answering to a partial query, best first, at most `AppConfig.Events.placeSuggestionCount`; empty when
    /// nothing does.
    func suggestions(for query: String) async -> [PlaceSuggestion]
}
