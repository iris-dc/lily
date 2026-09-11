import Foundation

/// Shares one fix between every caller of the wrapped service: concurrent requests await the same upstream call and
/// a recent result is reused, so two tabs asking for the user's position never open two CoreLocation streams.
/// The shared request deliberately survives a caller's cancellation (bounded by the upstream timeout): the fix it
/// obtains is remembered for whichever screen asks next.
final class CachedLocationService: LocationService {
    let upstream: any LocationService
    private let logger: any Logging
    private let now: () -> ContinuousClock.Instant
    private var remembered: RememberedFix?
    private var inFlight: Task<Coordinate?, Never>?

    init(upstream: any LocationService,
         logger: any Logging,
         now: @escaping () -> ContinuousClock.Instant = { .now }) {
        self.upstream = upstream
        self.logger = logger
        self.now = now
    }

    func currentLocation() async -> Coordinate? {
        if let remembered, remembered.isFresh(at: now()) {
            logger.debug(.cache, "Location cache hit")
            return remembered.coordinate
        }
        if let inFlight {
            logger.debug(.cache, "Location request joined the fix in flight")
            return await inFlight.value
        }
        logger.debug(.cache, "Location cache miss")
        let request = Task { await self.upstream.currentLocation() }
        inFlight = request
        let coordinate = await request.value
        inFlight = nil
        remembered = RememberedFix(coordinate: coordinate, takenAt: now())
        return coordinate
    }
}

/// A result and when it was taken. A missing fix expires sooner, so a later GPS fix is picked up quickly.
private struct RememberedFix {
    let coordinate: Coordinate?
    let takenAt: ContinuousClock.Instant

    func isFresh(at now: ContinuousClock.Instant) -> Bool {
        let lifetime = coordinate == nil ? AppConfig.Location.failedFixTTL : AppConfig.Location.fixTTL
        return takenAt.duration(to: now) < lifetime
    }
}
