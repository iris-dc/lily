import Foundation
import Testing
@testable import lily

struct MessageArrivalCurveTests {
    private let curve = MessageArrivalCurve(duration: 0.35, bounce: 0.25, startScale: 0.8)

    /// Nothing shows before the row arrived or at its first instant, so an appended row never flashes at full strength.
    @Test func aRowStartsInvisibleAtItsStartScale() {
        #expect(curve.frame(elapsed: -1) == MessageArrivalCurve.Frame(opacity: 0, scale: 0.8))
        #expect(curve.frame(elapsed: 0) == MessageArrivalCurve.Frame(opacity: 0, scale: 0.8))
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
}
