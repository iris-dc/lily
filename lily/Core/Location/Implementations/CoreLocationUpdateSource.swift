import CoreLocation

/// `CLLocationUpdate.liveUpdates` reduced to `LocationFix`es. Iterating it prompts for when-in-use permission.
nonisolated struct CoreLocationUpdateSource: LocationUpdateSource {
    func updates() -> AsyncThrowingStream<LocationFix, any Error> {
        AsyncThrowingStream { continuation in
            let forwarding = Task {
                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        continuation.yield(LocationFix(update))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in forwarding.cancel() }
        }
    }
}

private extension LocationFix {
    init(_ update: CLLocationUpdate) {
        self.init(coordinate: update.location.map { Coordinate($0.coordinate) },
                  isDenied: update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted)
    }
}
