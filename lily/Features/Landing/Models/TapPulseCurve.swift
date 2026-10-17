import Foundation

/// The ring over the join slide's Join button, frame by frame from a clock: it grows out of the button while it fades,
/// rests invisible, and starts again, `period` seconds a cycle. Pure arithmetic over the time since the ring started,
/// so nothing an interactive scroll or a relayout can interrupt: a `repeatForever` animation on the same ring had its
/// scale stall near the button while its opacity kept cycling and snapping back to full.
nonisolated struct TapPulseCurve: Equatable, Sendable {
    /// Seconds one cycle takes, the rest included.
    let period: TimeInterval
    /// The share of the cycle the ring is on screen; for the rest it is invisible at the button.
    let activeFraction: Double
    /// The share of the active part over which the ring fades in, so it never pops onto the screen.
    let fadeInFraction: Double
    /// How far the ring has grown by the end of the active part, relative to the button.
    let maxScale: Double
    /// The ring's opacity at its peak, the end of its fade-in; the fade-out runs from there to the end of the active part.
    let peakOpacity: Double

    /// The ring at one instant: how far it has grown and how visible it is.
    struct Frame: Equatable, Sendable {
        let scale: Double
        let opacity: Double

        static let resting = Frame(scale: 1, opacity: 0)
    }

    /// The Join ring of the intro, on its design tokens.
    static let intro = TapPulseCurve(period: DesignTokens.Duration.introPulsePeriod,
                                     activeFraction: DesignTokens.Layout.introPulseActiveFraction,
                                     fadeInFraction: DesignTokens.Layout.introPulseFadeInFraction,
                                     maxScale: DesignTokens.Layout.introPulseScale,
                                     peakOpacity: DesignTokens.Opacity.introPulse)

    /// Where in its cycle the ring is `elapsed` seconds after it started: `0 ..< 1`, wrapping every `period`.
    func phase(elapsed: TimeInterval) -> Double {
        let position = elapsed.truncatingRemainder(dividingBy: period)
        return (position < 0 ? position + period : position) / period
    }

    func frame(elapsed: TimeInterval) -> Frame {
        frame(atPhase: phase(elapsed: elapsed))
    }

    /// The ring at `phase` of its cycle: growing with an ease-out through the active part while it fades in linearly to
    /// its peak and then out linearly to nothing; invisible at the button for the rest.
    func frame(atPhase phase: Double) -> Frame {
        guard phase < activeFraction else { return .resting }
        let progress = phase / activeFraction
        let eased = 1 - (1 - progress) * (1 - progress)
        let fadeIn = progress / fadeInFraction
        let fadeOut = (1 - progress) / (1 - fadeInFraction)
        return Frame(scale: 1 + (maxScale - 1) * eased, opacity: peakOpacity * min(fadeIn, fadeOut))
    }
}
