import Foundation
import Testing
@testable import lily

@MainActor
struct BackoffTests {
    private func makeBackoff() -> Backoff { Backoff(table: [1, 2, 4], jitter: 0.5) }

    @Test func walksTheTableOneEntryPerCall() {
        var backoff = makeBackoff()
        let waits = (0..<3).map { _ in backoff.next(random: { _ in 0 }) }
        #expect(waits == [1, 2, 4])
        #expect(backoff.attempt == 3)
    }

    @Test func staysAtTheLastEntryPastTheEnd() {
        var backoff = makeBackoff()
        for _ in 0..<3 { _ = backoff.next(random: { _ in 0 }) }
        #expect(backoff.next(random: { _ in 0 }) == 4)
        #expect(backoff.next(random: { _ in 0 }) == 4)
    }

    @Test func jitterStaysWithinTheConfiguredFraction() {
        var high = makeBackoff()
        var low = makeBackoff()
        var offered: ClosedRange<Double>?
        let highWait = high.next(random: { range in
            offered = range
            return range.upperBound
        })
        let lowWait = low.next(random: { $0.lowerBound })
        #expect(highWait == 1.5)
        #expect(lowWait == 0.5)
        #expect(offered == -0.5...0.5)
    }

    @Test func resetStartsTheTableOver() {
        var backoff = makeBackoff()
        _ = backoff.next(random: { _ in 0 })
        _ = backoff.next(random: { _ in 0 })
        backoff.reset()
        #expect(backoff.attempt == 0)
        #expect(backoff.next(random: { _ in 0 }) == 1)
    }

    @Test func theDefaultsAreTheReconnectConfig() {
        let backoff = Backoff()
        #expect(backoff.table == AppConfig.Realtime.reconnectBackoffSeconds)
        #expect(backoff.jitter == AppConfig.Realtime.reconnectJitter)
        #expect(backoff.attempt == 0)
    }
}
