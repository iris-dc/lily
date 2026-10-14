import Foundation
import Testing
@testable import lily

/// The staleness rules every cached list shares, judged on their own.
struct ContentFreshnessTests {
    private static let start = Date(timeIntervalSince1970: 1_700_000_000)
    private static let berlin = Coordinate(latitude: 52.5231, longitude: 13.4049)
    /// Rounds to the same coarse position as `berlin` (52.52, 13.40).
    private static let nearby = Coordinate(latitude: 52.5235, longitude: 13.4040)
    private static let elsewhere = Coordinate(latitude: 52.60, longitude: 13.40)
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

    /// Nothing was loaded yet, so a known position has nothing to be compared with.
    @Test func aPositionIsNoReasonBeforeTheFirstLoad() {
        #expect(freshness.positionReason(for: Self.berlin) == nil)
        #expect(freshness.stalenessReason(now: Self.start, version: 0, userID: nil, position: Self.berlin) == "never loaded")
    }

    @Test func aLoadWithoutAPositionIsStaleOnceOneIsKnown() {
        var freshness = freshness
        freshness.recordSuccess(at: Self.start, version: 1, userID: "u")

        #expect(freshness.stalenessReason(now: Self.start, version: 1, userID: "u", position: nil) == nil)
        #expect(freshness.stalenessReason(now: Self.start, version: 1, userID: "u", position: Self.berlin)
            == "position became known")
    }

    /// The position is compared at the backend's rounding, so a drift of a few hundred metres never reloads.
    @Test func aMoveWithinTheRoundingIsNoReasonAndBeyondItIs() {
        var freshness = freshness
        freshness.recordSuccess(at: Self.start, version: 1, userID: "u", position: Self.berlin)

        #expect(freshness.positionReason(for: Self.berlin) == nil)
        #expect(freshness.positionReason(for: Self.nearby) == nil)
        #expect(freshness.positionReason(for: Self.elsewhere) == "position changed")
        #expect(freshness.positionReason(for: nil) == nil, "a list that sends no position is never stale for one")
    }

    @Test func theSharedReasonsComeBeforeThePosition() {
        var freshness = freshness
        freshness.recordSuccess(at: Self.start, version: 1, userID: "u", position: Self.berlin)
        let moved = Self.elsewhere

        #expect(freshness.stalenessReason(now: Self.start, version: 2, userID: "u", position: moved) == "changed elsewhere")
        #expect(freshness.stalenessReason(now: Self.start, version: 1, userID: nil, position: moved) == "caller changed")
        let expired = Self.start.addingTimeInterval(60)
        #expect(freshness.stalenessReason(now: expired, version: 1, userID: "u", position: moved) == "older than TTL")
        freshness.recordFailure(at: Self.start, version: 1, userID: "u")
        #expect(freshness.stalenessReason(now: Self.start, version: 1, userID: "u", position: moved) == "retry after failure")
    }

    @Test func aSuccessWithoutAPositionForgetsTheOneBefore() {
        var freshness = freshness
        freshness.recordSuccess(at: Self.start, version: 1, userID: "u", position: Self.berlin)
        freshness.recordSuccess(at: Self.start.addingTimeInterval(1), version: 1, userID: "u")

        #expect(freshness.positionReason(for: Self.berlin) == "position became known")
    }

    /// The one `switch` a store's load prologue makes: wait after a failure, reload when stale, reuse when fresh.
    @Test func decisionWaitsThenReloadsThenReusesInThatOrder() {
        var freshness = freshness
        #expect(freshness.decision(now: Self.start, version: 1, userID: "u") == .stale(reason: "never loaded"))

        freshness.recordFailure(at: Self.start, version: 1, userID: "u")
        #expect(freshness.decision(now: Self.start, version: 1, userID: "u") == .waitAfterFailure)
        let afterCooldown = Self.start.addingTimeInterval(10)
        #expect(freshness.decision(now: afterCooldown, version: 1, userID: "u") == .stale(reason: "retry after failure"))

        freshness.recordSuccess(at: afterCooldown, version: 1, userID: "u")
        #expect(freshness.decision(now: afterCooldown, version: 1, userID: "u") == .fresh)
        let afterTTL = afterCooldown.addingTimeInterval(60)
        #expect(freshness.decision(now: afterTTL, version: 1, userID: "u") == .stale(reason: "older than TTL"))
        #expect(freshness.decision(now: afterCooldown, version: 2, userID: "u") == .stale(reason: "changed elsewhere"))
    }

    @Test func resetForgetsEverythingButTheLimits() {
        var freshness = freshness
        freshness.recordSuccess(at: Self.start, version: 1, userID: "u", position: Self.berlin)
        freshness.recordFailure(at: Self.start.addingTimeInterval(1), version: 1, userID: "u")

        freshness.reset()

        #expect(freshness == ContentFreshness(staleAfter: 60, retryAfterFailure: 10))
        #expect(freshness.positionReason(for: Self.berlin) == nil)
    }

    /// The four lists (events, Mine, the inbox, the tournaments) build their freshness from `standard`, so the TTL and
    /// the cooldown are decided once in `AppConfig.Lists`.
    @Test func everyListSharesOneFreshnessRule() {
        var fresh = ContentFreshness.standard
        let loaded = Self.start
        fresh.recordSuccess(at: loaded, version: 1, userID: "u1")

        let justBeforeTTL = loaded.addingTimeInterval(AppConfig.Lists.staleAfter - 1)
        #expect(fresh.stalenessReason(now: justBeforeTTL, version: 1, userID: "u1") == nil)
        let atTTL = loaded.addingTimeInterval(AppConfig.Lists.staleAfter)
        #expect(fresh.stalenessReason(now: atTTL, version: 1, userID: "u1") == "older than TTL")

        let failed = atTTL
        fresh.recordFailure(at: failed, version: 1, userID: "u1")
        let justBeforeCooldown = failed.addingTimeInterval(AppConfig.Lists.retryAfterFailure - 1)
        #expect(fresh.isWaitingToRetry(now: justBeforeCooldown, version: 1, userID: "u1"))
        let atCooldown = failed.addingTimeInterval(AppConfig.Lists.retryAfterFailure)
        #expect(!fresh.isWaitingToRetry(now: atCooldown, version: 1, userID: "u1"))
    }
}
