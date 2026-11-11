import Foundation

nonisolated extension AppConfig.Events {
    /// How close to a stack's first spot an event must stand to join its pin, since overlapping pins left the one
    /// behind unselectable; geocoding one typed name twice lands at zero.
    static let mapStackRadiusMeters = 11.0
    /// Decimals of the first spot that name a stack, so the same spot keeps its identity across reloads.
    static let mapStackDecimals = 4
    /// The most place suggestions the create form shows under the name field.
    static let placeSuggestionCount = 3
    /// The breath after the last keystroke before the geocoder is asked, and the shortest query worth asking for.
    static let placeSuggestionDebounce: Duration = .milliseconds(300)
    static let placeSuggestionMinimumQuery = 2
    /// Side of the area, in metres, the geocoder and the suggestions favour around the draft's spot or the user: about
    /// a metro area, so a venue name resolves nearby. Only a hint, so a typed city name still lands on the city.
    static let placeSearchRegionMeters: Double = 100_000
}

nonisolated extension AppConfig.Events.Creation {
    /// The finish time proposed when the host adds one: an hour past the start, a round default to edit from.
    static let proposedDuration: TimeInterval = .hour
}
