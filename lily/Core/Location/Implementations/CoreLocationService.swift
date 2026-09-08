import CoreLocation
import Foundation

/// Wraps `CLLocationUpdate.liveUpdates`, which prompts for when-in-use permission on first use.
final class CoreLocationService: LocationService {
    private let logger: any Logging
    private let timeout: Duration

    init(logger: any Logging, timeout: Duration = AppConfig.Location.fixTimeout) {
        self.logger = logger
        self.timeout = timeout
    }

    func currentLocation() async -> Coordinate? {
        let task = Task { try await firstFix() }
        let timeoutTask = Task {
            try await Task.sleep(for: timeout)
            task.cancel()
        }
        defer { timeoutTask.cancel() }
        do {
            let coordinate = try await task.value
            logger.info(.location, "Location fix acquired")
            return coordinate
        } catch {
            logger.warning(.location, "Location unavailable: \(error)")
            return nil
        }
    }

    private func firstFix() async throws -> Coordinate? {
        for try await update in CLLocationUpdate.liveUpdates() {
            if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                logger.info(.location, "Location permission denied")
                return nil
            }
            if let location = update.location {
                return Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            }
        }
        return nil
    }
}
