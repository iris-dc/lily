import Foundation
import Testing
@testable import lily

struct TapPulseCurveTests {
    /// A two-second cycle, on screen for its first second, fading in over the first tenth of that.
    private let curve = TapPulseCurve(period: 2, activeFraction: 0.5, fadeInFraction: 0.1, maxScale: 1.8, peakOpacity: 0.7)

    @Test func thePhaseWrapsEveryPeriodAndNeverRunsBackwards() {
        #expect(curve.phase(elapsed: 0) == 0)
        #expect(curve.phase(elapsed: 0.5) == 0.25)
        #expect(curve.phase(elapsed: 2) == 0)
        #expect(curve.phase(elapsed: 3) == 0.5)
        #expect(curve.phase(elapsed: -0.5) == 0.75)
    }

    /// Both ends of the active part are invisible, so neither the start of a cycle nor its end can flash.
    @Test func aCycleStartsAtTheButtonInvisibleAndEndsInvisibleAtFullSize() {
        #expect(curve.frame(atPhase: 0) == .resting)
        let end = curve.frame(atPhase: 0.5 - 1e-9)
        #expect(isAbout(end.scale, 1.8))
        #expect(isAbout(end.opacity, 0))
    }

    @Test func theRingGrowsAndFadesTogetherThroughTheActivePart() {
        let frames = stride(from: 0.06, through: 0.49, by: 0.01).map { curve.frame(atPhase: $0) }
        for (earlier, later) in zip(frames, frames.dropFirst()) {
            #expect(later.scale > earlier.scale)
            #expect(later.opacity < earlier.opacity)
        }
    }

    /// The token is the ring's true peak, reached at the end of the fade-in; the fade-out runs from there.
    @Test func theRingFadesInToItsPeakBeforeItFadesOut() {
        let halfwayIn = curve.frame(atPhase: 0.025)
        let peak = curve.frame(atPhase: 0.05)
        #expect(isAbout(halfwayIn.opacity, 0.35))
        #expect(isAbout(peak.opacity, 0.7))
        #expect(isAbout(curve.frame(atPhase: 0.275).opacity, 0.35))
        #expect(halfwayIn.scale > 1)
    }

    @Test func theRestIsInvisibleAtTheButton() {
        for phase in [0.5, 0.7, 0.999] {
            #expect(curve.frame(atPhase: phase) == .resting)
        }
        #expect(curve.frame(elapsed: 1.5) == .resting)
    }

    @Test func theIntroRingReadsItsTokens() {
        let intro = TapPulseCurve.intro
        #expect(intro.period == DesignTokens.Duration.introPulsePeriod)
        #expect(intro.activeFraction == DesignTokens.Layout.introPulseActiveFraction)
        #expect(intro.fadeInFraction == DesignTokens.Layout.introPulseFadeInFraction)
        #expect(intro.maxScale == DesignTokens.Layout.introPulseScale)
        #expect(intro.peakOpacity == DesignTokens.Opacity.introPulse)
    }

    /// The tokens themselves could bring the reported ring back (one that never grows, or never shows): the intro ring
    /// must have a cycle, grow past the button, show up, fade in and rest.
    @Test func theIntroRingGrowsShowsAndRests() {
        let intro = TapPulseCurve.intro
        #expect(intro.period > 0)
        #expect(intro.maxScale > 1)
        #expect(intro.peakOpacity > 0 && intro.peakOpacity <= 1)
        #expect(intro.activeFraction > 0 && intro.activeFraction < 1)
        #expect(intro.fadeInFraction > 0 && intro.fadeInFraction < 1)
        #expect(intro.frame(atPhase: 0) == .resting)
        let midway = intro.frame(atPhase: intro.activeFraction / 2)
        #expect(midway.scale > 1 && midway.opacity > 0)
        #expect(isAbout(intro.frame(atPhase: intro.activeFraction * intro.fadeInFraction).opacity, intro.peakOpacity))
        #expect(intro.frame(atPhase: intro.activeFraction) == .resting)
    }

    private func isAbout(_ value: Double, _ expected: Double) -> Bool {
        abs(value - expected) < 1e-6
    }
}
