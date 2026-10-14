import Foundation

/// When the connection renews itself: at `exp - reconnectBeforeExpiry` or at `maxConnectionAge`, whichever is first.
/// A refreshed token whose `exp` is not later than the last one's, or a token already inside the renewal margin, would
/// renew at once and loop: those waits fall into the backoff table instead, and never before the expiry-bound moment.
nonisolated struct RenewalDelay: Equatable, Sendable {
    enum Reason: Equatable, Sendable {
        case scheduled
        case staleToken
        case insideMargin
    }

    /// The expiry-bound wait: `exp - margin - now`, at most `maxConnectionAge`; `maxConnectionAge` without an `exp`.
    let bound: TimeInterval
    let reason: Reason

    init(expiry: Date?, lastExpiry: Date?, now: Date, fresh: Bool) {
        let maxAge = AppConfig.Realtime.maxConnectionAge
        let untilExpiryBound = expiry.map { $0.timeIntervalSince(now) - AppConfig.Realtime.reconnectBeforeExpiry }
        bound = min(untilExpiryBound ?? maxAge, maxAge)
        if fresh, let expiry, let lastExpiry, expiry <= lastExpiry {
            reason = .staleToken
        } else if let untilExpiryBound, untilExpiryBound <= 0 {
            reason = .insideMargin
        } else {
            reason = .scheduled
        }
    }

    /// The wait to sleep: the bound for `.scheduled`, which also starts the backoff over; for the other two reasons
    /// the later of the bound and the backoff's next wait.
    func seconds(backingOff backoff: inout Backoff, random: (ClosedRange<Double>) -> Double) -> TimeInterval {
        guard reason != .scheduled else {
            backoff.reset()
            return bound
        }
        return max(bound, backoff.next(random: random))
    }
}
