import Foundation

nonisolated extension AppConfig.Events {
    /// Decimals at which two events count as the same spot on the map (about 11 m) and stack into one pin, since
    /// overlapping pins left the one behind unselectable; geocoding one typed name twice lands exactly here.
    static let mapStackDecimals = 4
    /// The most place suggestions the create form shows under the name field.
    static let placeSuggestionCount = 3
    /// The breath after the last keystroke before the geocoder is asked, and the shortest query worth asking for.
    static let placeSuggestionDebounce: Duration = .milliseconds(300)
    static let placeSuggestionMinimumQuery = 2
}
