import Foundation
import Testing
@testable import lily

/// The staleness rules every cached list shares, judged on their own.
struct ContentFreshnessTests {
    private static let start = Date(timeIntervalSince1970: 1_700_000_000)
    private let freshness = ContentFreshness(staleAfter: 60, retryAfterFailure: 10)

    @Test func neverLoadedIsStaleAndNotWaiting() {
        #expect(!freshness.hasLoaded && !freshness.loadFailed)
        #expect(freshness.stalenessReason(now: Self.start, version: 0, userID: nil) == "never loaded")
        #expect(!freshness.isWaitingToRetry(now: Self.start, version: 0, userID: nil))
    }

    @Test func aSuccessIsFreshUntilTheTTLOrAChange() {
        var freshness = freshness
        freshness.recordSuccess(at: Self.start, version: 1, userID: "u")

        #expect(freshness.hasLoaded && freshness.lastLoadedAt == Self.start)
        #expect(freshness.stalenessReason(now: Self.start.addingTimeInterval(59), version: 1, userID: "u") == nil)
        #expect(freshness.stalenessReason(now: Self.start.addingTimeInterval(60), version: 1, userID: "u") == "older than TTL")
        #expect(freshness.stalenessReason(now: Self.start, version: 2, userID: "u") == "changed elsewhere")
        #expect(freshness.stalenessReason(now: Self.start, version: 1, userID: nil) == "caller changed")
    }

    /// A change applied in place is current for its version, so the list does not reload for its own change.
    @Test func acknowledgingAVersionKeepsTheContentFresh() {
        var freshness = freshness
        freshness.recordSuccess(at: Self.start, version: 1, userID: "u")
        freshness.acknowledge(version: 2)

        #expect(freshness.stalenessReason(now: Self.start, version: 2, userID: "u") == nil)
    }

    @Test func aFailureWaitsForTheCooldownUnlessTheAnswerChanged() {
        var freshness = freshness
        freshness.recordFailure(at: Self.start, version: 1, userID: "u")

        #expect(freshness.loadFailed && !freshness.hasLoaded)
        #expect(freshness.stalenessReason(now: Self.start, version: 1, userID: "u") == "retry after failure")
        #expect(freshness.isWaitingToRetry(now: Self.start.addingTimeInterval(9), version: 1, userID: "u"))
        #expect(!freshness.isWaitingToRetry(now: Self.start.addingTimeInterval(10), version: 1, userID: "u"))
        #expect(!freshness.isWaitingToRetry(now: Self.start, version: 2, userID: "u"), "a change elsewhere ends the wait")
        #expect(!freshness.isWaitingToRetry(now: Self.start, version: 1, userID: "v"), "a change of caller ends the wait")
    }

    /// A failure after a success keeps the old content on screen and marks it for a retry.
    @Test func aFailureAfterASuccessIsStaleAndASuccessClearsIt() {
        var freshness = freshness
        freshness.recordSuccess(at: Self.start, version: 1, userID: "u")
        freshness.recordFailure(at: Self.start.addingTimeInterval(1), version: 1, userID: "u")
        #expect(freshness.hasLoaded && freshness.loadFailed)
        let later = Self.start.addingTimeInterval(1)
        #expect(freshness.stalenessReason(now: later, version: 1, userID: "u") == "retry after failure")

        freshness.recordSuccess(at: Self.start.addingTimeInterval(2), version: 1, userID: "u")
        #expect(!freshness.loadFailed)
        #expect(freshness.stalenessReason(now: Self.start.addingTimeInterval(2), version: 1, userID: "u") == nil)
    }

    @Test func resetForgetsEverythingButTheLimits() {
        var freshness = freshness
        freshness.recordFailure(at: Self.start, version: 1, userID: "u")

        freshness.reset()

        #expect(freshness == ContentFreshness(staleAfter: 60, retryAfterFailure: 10))
    }
}
