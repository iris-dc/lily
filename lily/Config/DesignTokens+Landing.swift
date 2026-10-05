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
    /// The share of the miniature's height that fades out at the bottom, so the screen reads as continuing below.
    static let introScreenFadeFraction: CGFloat = 0.3
    /// The miniature draws its text at this size whatever the user's, as a screenshot would.
    static let introScreenTypeSize: DynamicTypeSize = .xSmall
    /// The ring pulsing over the Join button of the second slide: how far it grows, its stroke, and how much of its
    /// slide must be on screen for it to run (the pager holds every slide, so off-screen ones would pulse for nothing).
    static let introPulseScale: CGFloat = 1.8
    static let introPulseLineWidth: CGFloat = 2
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
    /// One pulse of the ring over the Join button.
    static let introPulsePeriod: TimeInterval = 1.8
}

nonisolated extension DesignTokens.Opacity {
    /// A page bar of a slide that is not on screen.
    static let introPageBarInactive: Double = 0.25
    /// A slide while it leaves the page.
    static let introSlideLeaving: Double = 0.3
    /// The screen frame's fill and stroke over the aurora.
    static let introScreenFill: Double = 0.6
    static let introScreenStroke: Double = 0.14
    /// The pulsing ring at its start, before it fades.
    static let introPulse: Double = 0.7
}
