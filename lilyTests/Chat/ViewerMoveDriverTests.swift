import SwiftUI
import Testing
@testable import lily

/// Where a move is at a moment of its run (its curve over the time gone, whole once the duration is), and a run's
/// frames, end and cancellation on a clock ticked by hand.
@MainActor
struct ViewerMoveDriverTests {
    private typealias Duration = DesignTokens.Duration

    @Test func theWayFollowsTheCurveOverTheDurationAndEndsWhole() {
        #expect(ViewerMoveDriver.fraction(elapsed: 0, duration: 0.28, curve: .linear) == 0)
        #expect(ViewerMoveDriver.fraction(elapsed: 0.14, duration: 0.28, curve: .linear) == 0.5)
        #expect(ViewerMoveDriver.fraction(elapsed: 0.28, duration: 0.28, curve: .linear) == 1)
        #expect(ViewerMoveDriver.fraction(elapsed: 1, duration: 0.28, curve: .linear) == 1, "late frames end the move")
        #expect(ViewerMoveDriver.fraction(elapsed: -0.01, duration: 0.28, curve: .linear) == 0, "a clock not yet started")
        #expect(ViewerMoveDriver.fraction(elapsed: 0, duration: 0, curve: .linear) == 1, "no duration is already there")
    }

    /// One 60 Hz frame into the move: a few percent of the way from rest, a fifth of it out of a drag.
    @Test func theViewersCurvesStartGentlyFromRestAndAtSpeedOutOfADrag() {
        let (elapsed, duration) = (1.0 / 60, Duration.viewerTransition)
        let fromRest = ViewerMoveDriver.fraction(elapsed: elapsed, duration: duration, curve: Duration.viewerTransitionCurve)
        let fromDrag = ViewerMoveDriver.fraction(elapsed: elapsed, duration: duration, curve: Duration.viewerThrowCurve)
        #expect(fromRest < 0.1 && fromDrag > 0.1)
    }

    @Test func aRunWritesTheWayEveryFrameAndHandsOverOnceAtTheEnd() {
        let clock = FakeFrameClock()
        let driver = ViewerMoveDriver(clock: clock)
        var ways: [Double] = []
        var completions = 0
        driver.run(duration: 1, curve: .linear, now: 10, apply: { ways.append($0) }, completion: { completions += 1 })
        #expect(driver.isRunning && clock.isRunning)
        clock.tick(at: 10.5)
        clock.tick(at: 11)
        clock.tick(at: 11.5)
        #expect(ways == [0.5, 1], "the frame past the end is not written")
        #expect(completions == 1)
        #expect(!driver.isRunning && !clock.isRunning, "the clock stops with the move")
    }

    @Test func aNewRunDropsTheOneBeforeAndItsCompletion() {
        let clock = FakeFrameClock()
        let driver = ViewerMoveDriver(clock: clock)
        var ended: [String] = []
        driver.run(duration: 1, curve: .linear, now: 0, apply: { _ in }, completion: { ended.append("first") })
        driver.run(duration: 1, curve: .linear, now: 5, apply: { _ in }, completion: { ended.append("second") })
        clock.tick(at: 6)
        #expect(ended == ["second"])
    }

    @Test func cancelEndsARunWithoutItsCompletion() {
        let clock = FakeFrameClock()
        let driver = ViewerMoveDriver(clock: clock)
        var written = 0
        var completions = 0
        driver.run(duration: 1, curve: .linear, now: 0, apply: { _ in written += 1 }, completion: { completions += 1 })
        driver.cancel()
        clock.tick(at: 1)
        #expect(written == 0 && completions == 0 && !driver.isRunning)
    }
}
