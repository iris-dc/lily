import Foundation
import Synchronization
@testable import lily

/// Scripted location updates: yields the given fixes, then stays open like CoreLocation until cancelled, finishes
/// cleanly with `finishes`, or fails with `error`. Records whether the consumer tore the stream down.
final class FakeLocationUpdateSource: LocationUpdateSource, Sendable {
    private let fixes: [LocationFix]
    private let error: (any Error)?
    private let finishes: Bool
    private let terminated = Mutex(false)

    var wasTerminated: Bool { terminated.withLock { $0 } }

    init(fixes: [LocationFix] = [], error: (any Error)? = nil, finishes: Bool = false) {
        self.fixes = fixes
        self.error = error
        self.finishes = finishes
    }

    func updates() -> AsyncThrowingStream<LocationFix, any Error> {
        AsyncThrowingStream { continuation in
            fixes.forEach { continuation.yield($0) }
            if let error {
                continuation.finish(throwing: error)
            } else if finishes {
                continuation.finish()
            }
            continuation.onTermination = { [self] _ in terminated.withLock { $0 = true } }
        }
    }
}

/// Counts requests and, while `holdsRequests`, parks `currentLocation()` until `releaseRequests()`, to test coalescing
/// of concurrent callers. Observes cancellation like the real stream, so a test can tell a shared request that outlived
/// a caller's cancellation from one cancelled with it.
@MainActor
final class FakeLocationService: LocationService, HoldsRequests {
    var result: Coordinate?
    let hold = RequestHold()
    private(set) var callCount = 0
    /// Requests whose task was cancelled by the time they were released; they answer `nil` like a cancelled stream.
    private(set) var cancelledCount = 0

    func currentLocation() async -> Coordinate? {
        callCount += 1
        await hold.wait()
        if Task.isCancelled {
            cancelledCount += 1
            return nil
        }
        return result
    }
}
