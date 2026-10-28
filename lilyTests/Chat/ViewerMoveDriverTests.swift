import SwiftUI
import Testing
@testable import lily

/// Where a move is at a moment of its run: its curve over the time gone, whole once the duration is.
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
}
