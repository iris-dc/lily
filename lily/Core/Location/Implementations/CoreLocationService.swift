import Foundation

/// One fix from the live update stream, or `nil` when permission is denied or nothing arrives within the timeout.
final class CoreLocationService: LocationService {
    private let logger: any Logging
    private let timeout: Duration
    private let source: any LocationUpdateSource

    init(logger: any Logging,
         timeout: Duration = AppConfig.Location.fixTimeout,
         source: any LocationUpdateSource = CoreLocationUpdateSource()) {
        self.logger = logger
        self.timeout = timeout
        self.source = source
    }

    func currentLocation() async -> Coordinate? {
        do {
            guard let coordinate = try await firstFixBeforeTimeout() else {
                logger.info(.location, "No location fix (permission denied or no update within \(timeout))")
                return nil
            }
            logger.info(.location, "Location fix acquired")
            return coordinate
        } catch {
            logger.warning(.location, "Location unavailable: \(error)")
            return nil
        }
    }

    /// Races the stream against the timeout in one structured group, so cancelling the caller closes the stream too.
    private func firstFixBeforeTimeout() async throws -> Coordinate? {
        let timeout = timeout
        return try await withThrowingTaskGroup(of: Coordinate?.self) { group in
            group.addTask { try await self.firstFix() }
            group.addTask {
                try await Task.sleep(for: timeout)
                return nil
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { return nil }
            return first
        }
    }

    private func firstFix() async throws -> Coordinate? {
        for try await fix in source.updates() {
            if fix.isDenied {
                logger.info(.location, "Location permission denied")
                return nil
            }
            if let coordinate = fix.coordinate {
                return coordinate
            }
        }
        // A cancelled stream ends quietly; surface the cancellation instead of reporting an empty stream.
        try Task.checkCancellation()
        return nil
    }
}
