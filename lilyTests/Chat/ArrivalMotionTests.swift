import Foundation
import Testing
@testable import lily

/// The arrival's motion as the log sums it up: a glide is many small steps, a jump one big one, and the passes of one
/// frame count as the last of them.
struct ArrivalMotionTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)
    private let frame = 1.0 / 120

    @Test func aGlideIsManySmallSteps() {
        var motion = ArrivalMotion(rowID: "c-1", offset: 600, contentHeight: 1_100)
        for step in 1 ... 19 {
            let moved = CGFloat(step) * 3
            motion.record(offset: 600 + moved, contentHeight: 1_100 + moved, at: start + Double(step) * frame)
        }
        #expect(motion.summary == "offset +57 and content +57 over 19 frames, largest step 3")
    }

    @Test func aJumpIsOneStepNearTheWholeTravel() {
        var motion = ArrivalMotion(rowID: "c-2", offset: 600, contentHeight: 1_100)
        motion.record(offset: 657, contentHeight: 1_157, at: start)
        motion.record(offset: 657, contentHeight: 1_157, at: start + frame)
        #expect(motion.summary == "offset +57 and content +57 over 2 frames, largest step 57")
    }

    /// The lazy stack's estimate and its correction land in one frame: the screen shows only the corrected layout.
    @Test func theLayoutPassesOfOneFrameCountAsTheLast() {
        var motion = ArrivalMotion(rowID: "c-3", offset: 600, contentHeight: 1_100)
        motion.record(offset: 677, contentHeight: 1_177, at: start)
        motion.record(offset: 600, contentHeight: 1_100, at: start + 0.001)
        motion.record(offset: 603, contentHeight: 1_103, at: start + frame)
        #expect(motion.summary == "offset +3 and content +3 over 2 frames, largest step 3")
    }
}
