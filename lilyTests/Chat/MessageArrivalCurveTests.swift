import Foundation
import Testing
@testable import lily

struct MessageArrivalCurveTests {
    private let curve = MessageArrivalCurve(duration: 0.35, bounce: 0.25, startScale: 0.8)

    /// Nothing shows and nothing is taken before the row arrived or at its first instant, so an appended row never
    /// flashes at full strength and the rows above start from where they were.
    @Test func aRowStartsInvisibleAtItsStartScaleWithNoHeight() {
        #expect(curve.frame(elapsed: -1) == MessageArrivalCurve.Frame(opacity: 0, scale: 0.8, reveal: 0))
        #expect(curve.frame(elapsed: 0) == MessageArrivalCurve.Frame(opacity: 0, scale: 0.8, reveal: 0))
    }

    /// The height the row takes only ever grows, from nothing to all of it, so the rows above move up and never back.
    @Test func theRowTakesItsHeightWithoutOvershoot() {
        let frames = stride(from: 0.0, to: curve.settlingDuration, by: 1.0 / 120).map { curve.frame(elapsed: $0) }
        for (earlier, later) in zip(frames, frames.dropFirst()) {
            #expect(later.reveal >= earlier.reveal)
        }
        #expect(frames.allSatisfy { (0 ... 1).contains($0.reveal) })
        #expect(curve.frame(elapsed: curve.duration).reveal > 0.9)
        #expect(curve.frame(elapsed: curve.settlingDuration).reveal == 1)
    }

    @Test func aRowRestsOnceTheSpringHasSettled() {
        #expect(curve.settlingDuration > curve.duration)
        #expect(curve.frame(elapsed: curve.settlingDuration) == .resting)
        #expect(curve.frame(elapsed: 60) == .resting)
    }

    /// The fade only ever brightens and stops at full; the scale grows past full and back, the spring's bounce.
    @Test func theRowFadesInWhileItGrowsWithABounce() {
        let frames = stride(from: 0.0, to: curve.settlingDuration, by: 1.0 / 120).map { curve.frame(elapsed: $0) }
        for (earlier, later) in zip(frames, frames.dropFirst()) {
            #expect(later.opacity >= earlier.opacity)
        }
        #expect(frames.allSatisfy { (0 ... 1).contains($0.opacity) })
        #expect(frames.contains { $0.scale > 1 }, "the bounce overshoots full size")
        let early = curve.frame(elapsed: curve.duration / 4)
        #expect(early.opacity > 0 && early.opacity < 1, "a quarter in, the row is still fading")
        #expect(early.scale > 0.8 && early.scale < 1)
    }

    /// Most of the fade lands within the token's duration, so it reads as one beat with the rows' slide.
    @Test func theRowIsNearlyAtFullStrengthByTheDuration() {
        #expect(curve.frame(elapsed: curve.duration).opacity > 0.9)
    }

    @Test func theStandardCurveIsTheTokens() {
        #expect(MessageArrivalCurve.standard.duration == DesignTokens.MessageArrival.duration)
        #expect(MessageArrivalCurve.standard.bounce == DesignTokens.MessageArrival.bounce)
        #expect(MessageArrivalCurve.standard.startScale == Double(DesignTokens.MessageArrival.scale))
    }

    /// Under Reduce Motion the row is whole from its first frame and never arrives: a duration of 0 is no spring, so the
    /// curve answers before one is built (`Spring(duration: 0)` is undefined).
    @Test func theStillCurveRestsFromTheFirstFrameAndSettlesAtOnce() {
        let still = MessageArrivalCurve.still
        #expect(still.duration == 0)
        #expect(still.settlingDuration == 0)
        #expect(still.frame(elapsed: -1) == .resting)
        #expect(still.frame(elapsed: 0) == .resting)
        #expect(still.frame(elapsed: 0.001) == .resting)
        #expect(still.frame(elapsed: 60) == .resting)
    }
}
