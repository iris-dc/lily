import Foundation

/// One-shot access to the user's position. Permission prompting is the implementation's concern.
protocol LocationService {
    /// Resolves to `nil` when permission is denied or no fix arrives in time. Never throws to the UI.
    func currentLocation() async -> Coordinate?
}
