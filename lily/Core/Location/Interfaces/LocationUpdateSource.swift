import Foundation

/// A stream of raw location updates. The seam between `CoreLocationService` and CoreLocation, so the
/// timeout, permission and first-fix logic can be tested against a scripted source.
nonisolated protocol LocationUpdateSource {
    /// Opens a fresh stream of updates; it stays open until the consumer stops iterating.
    func updates() -> AsyncThrowingStream<LocationFix, any Error>
}
