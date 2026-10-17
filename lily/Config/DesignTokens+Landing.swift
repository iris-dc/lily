import SwiftUI

nonisolated extension DesignTokens.Symbols {
    /// The swipe hint under the intro's first caption.
    static let swipeUp = "chevron.up"
}

nonisolated extension DesignTokens.Layout {
    /// The page bars at the pager's trailing edge, one per slide, the current one long. Vertical on purpose: a row of
    /// bars under the slides read as "swipe sideways".
    static let introPageBarThickness: CGFloat = 4
    static let introPageBarLength: CGFloat = 16
    static let introPageBarActiveLength: CGFloat = 40
    /// The framed miniature of a real screen on every slide: its width, its stroke, and its height where the pager has
    /// no page height to fill (accessibility type sizes).
    static let introScreenWidth: CGFloat = 300
    static let introScreenStrokeWidth: CGFloat = 1
    static let introScreenAccessibilityHeight: CGFloat = 320
    /// The tallest the miniature gets on a compact width, relative to its width: a detail down to its Join fits snugly,
    /// and a taller page splits what is left above the frame and under the caption instead of showing an empty screen.
    static let introScreenMaxAspect: CGFloat = 1.3
    /// The share of the miniature's height that fades out at the bottom, so the screen reads as continuing below.
    static let introScreenFadeFraction: CGFloat = 0.3
    /// How much of a bottom-aligned miniature fades out at the top once its screen is taller than the frame, and how
    /// much taller it must be for that to count (sub-point layout rounding is not a crop).
    static let introScreenTopFadeLength: CGFloat = 40
    static let introScreenOverflowTolerance: CGFloat = 1
    /// The miniature draws its text at this size whatever the user's, as a screenshot would.
    static let introScreenTypeSize: DynamicTypeSize = .xSmall
    /// The ring pulsing over the Join button of the second slide (`TapPulseCurve`): how far it grows, its stroke, the
    /// share of each cycle it is on screen (the rest it rests invisible, so the pulses read as taps), the share of that
    /// over which it fades in rather than pops, and how much of the ring itself must be on screen for it to run (the
    /// pager holds every slide, so a ring on an off-screen slide would pulse for nothing).
    static let introPulseScale: Double = 1.8
    static let introPulseLineWidth: CGFloat = 2
    static let introPulseActiveFraction: Double = 0.65
    static let introPulseFadeInFraction: Double = 0.12
    static let introPulseVisibilityThreshold: Double = 0.5
    /// Every slide reserves this row for the swipe hint, so the captions sit at one height whether it shows or not.
    static let introHintRowHeight: CGFloat = 24
    /// A slide shrinks to this while it leaves the page and the next one comes in.
    static let introSlideLeavingScale: CGFloat = 0.92
}

nonisolated extension DesignTokens.Radius {
    /// The corner of the intro's screen frame, a phone's.
    static let screen: CGFloat = 32
}

nonisolated extension DesignTokens.Duration {
    /// Pause between two bounces of the swipe hint's chevron.
    static let introHintBouncePause: TimeInterval = 1.5
    /// One cycle of the ring over the Join button, its rest included.
    static let introPulsePeriod: TimeInterval = 2
}

nonisolated extension DesignTokens.Opacity {
    /// A page bar of a slide that is not on screen.
    static let introPageBarInactive: Double = 0.25
    /// A slide while it leaves the page.
    static let introSlideLeaving: Double = 0.3
    /// The screen frame's fill and stroke over the aurora.
    static let introScreenFill: Double = 0.6
    static let introScreenStroke: Double = 0.14
    /// The pulsing ring at its peak, the end of its fade-in; it fades out from there.
    static let introPulse: Double = 0.7
}
