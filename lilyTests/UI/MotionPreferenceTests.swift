import Testing
@testable import lily

/// The one rule every animation site reads: Reduce Motion on is `.reduced`, and only `.full` lets anything move.
struct MotionPreferenceTests {
    @Test func reduceMotionOnIsReducedAndOffIsFull() {
        #expect(MotionPreference.resolve(reduceMotion: true) == .reduced)
        #expect(MotionPreference.resolve(reduceMotion: false) == .full)
    }

    @Test func onlyFullAllowsMovement() {
        #expect(MotionPreference.full.allowsMovement)
        #expect(!MotionPreference.reduced.allowsMovement)
    }
}
