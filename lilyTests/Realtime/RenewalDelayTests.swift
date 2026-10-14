import Foundation
import Testing
@testable import lily

@MainActor
struct RenewalDelayTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let margin = AppConfig.Realtime.reconnectBeforeExpiry
    private let maxAge = AppConfig.Realtime.maxConnectionAge

    /// Expiries as seconds from `now`, so a test reads as the token it describes.
    private func makeDelay(expiry: TimeInterval?, lastExpiry: TimeInterval? = nil, fresh: Bool = false) -> RenewalDelay {
        RenewalDelay(expiry: expiry.map { now.addingTimeInterval($0) },
                     lastExpiry: lastExpiry.map { now.addingTimeInterval($0) },
                     now: now,
                     fresh: fresh)
    }

    @Test func aGoodTokenRenewsAtItsExpiryBound() {
        let delay = makeDelay(expiry: 3600)
        #expect(delay.bound == 3600 - margin)
        #expect(delay.reason == .scheduled)
    }

    @Test func withoutAnExpiryTheConnectionAgeBounds() {
        let delay = makeDelay(expiry: nil)
        #expect(delay.bound == maxAge)
        #expect(delay.reason == .scheduled)
        #expect(makeDelay(expiry: nil, lastExpiry: 3600, fresh: true).reason == .scheduled)
    }

    @Test func aFarExpiryIsCappedAtTheConnectionAge() {
        let delay = makeDelay(expiry: 2 * 86_400)
        #expect(delay.bound == maxAge)
        #expect(delay.reason == .scheduled)
    }

    @Test func aRefreshedTokenExpiringNoLaterThanTheLastIsStale() {
        #expect(makeDelay(expiry: 3600, lastExpiry: 3600, fresh: true).reason == .staleToken)
        #expect(makeDelay(expiry: 1800, lastExpiry: 3600, fresh: true).reason == .staleToken)
    }

    @Test func aFirstTokenEqualToTheLastIsNotStale() {
        #expect(makeDelay(expiry: 3600, lastExpiry: 3600, fresh: false).reason == .scheduled)
    }

    @Test func aRefreshedTokenExpiringLaterIsScheduled() {
        let delay = makeDelay(expiry: 3600, lastExpiry: 1800, fresh: true)
        #expect(delay.reason == .scheduled)
        #expect(delay.bound == 3600 - margin)
    }

    @Test func aTokenInsideTheMarginBacksOff() {
        let delay = makeDelay(expiry: 60)
        #expect(delay.reason == .insideMargin)
        #expect(delay.bound == 60 - margin)
        #expect(makeDelay(expiry: margin).reason == .insideMargin)
    }

    @Test func aStaleTokenInsideTheMarginReadsAsStale() {
        #expect(makeDelay(expiry: 60, lastExpiry: 60, fresh: true).reason == .staleToken)
    }

    @Test func secondsForAGoodTokenIsTheBoundAndResetsTheBackoff() {
        var backoff = Backoff(table: [1, 2, 4], jitter: 0)
        _ = backoff.next(random: { _ in 0 })
        _ = backoff.next(random: { _ in 0 })
        let delay = makeDelay(expiry: 3600)
        let seconds = delay.seconds(backingOff: &backoff, random: { _ in 0 })
        #expect(seconds == delay.bound)
        #expect(backoff.attempt == 0)
    }

    @Test func secondsForAStaleTokenNeverFallsBeforeTheBound() {
        var backoff = Backoff(table: [1, 2, 4], jitter: 0)
        let delay = makeDelay(expiry: 3600, lastExpiry: 3600, fresh: true)
        let seconds = delay.seconds(backingOff: &backoff, random: { _ in 0 })
        #expect(seconds == 3600 - margin)
        #expect(backoff.attempt == 1)
    }

    @Test func secondsInsideTheMarginIsTheBackoffsWait() {
        var backoff = Backoff(table: [1, 2, 4], jitter: 0.2)
        let delay = makeDelay(expiry: 60)
        let seconds = delay.seconds(backingOff: &backoff, random: { $0.upperBound })
        #expect(abs(seconds - 1.2) < 0.000_001)
        #expect(backoff.attempt == 1)
    }
}
