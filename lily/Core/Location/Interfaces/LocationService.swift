import Foundation

/// One-shot access to the user's position. Permission prompting is the implementation's concern.
protocol LocationService {
    /// Resolves to `nil` when permission is denied or no fix arrives in time. Never throws to the UI.
    func currentLocation() async -> Coordinate?

    /// Drops a remembered "no fix" so the next `currentLocation()` asks again; a known position is kept.
    /// Called when permission may just have changed (the app returns to the foreground). Caches implement it.
    func forgetMissingFix()
}

extension LocationService {
    func forgetMissingFix() {}
}
