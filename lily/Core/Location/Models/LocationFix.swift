import Foundation

/// One update from a location source, reduced to what the service acts on. Framework-free so fakes can script it.
nonisolated struct LocationFix: Equatable, Sendable {
    /// The position, or `nil` for updates that only carry status (permission, accuracy) and no location.
    let coordinate: Coordinate?
    /// The user denied, or the system restricted, location access; no fix will follow.
    let isDenied: Bool
}
