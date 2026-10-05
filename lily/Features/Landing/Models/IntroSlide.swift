import Foundation

/// The intro's pages in swipe order, one question each: what this is, how it is used, what else it offers.
nonisolated enum IntroSlide: String, CaseIterable, Identifiable, Sendable {
    case discover, join, create

    static let first: IntroSlide = .discover

    var id: String { rawValue }

    /// Two short lines; the slide draws the second in the accent colour.
    var headline: [String] { AppBranding.Intro.headline(for: self) }
    var message: String { AppBranding.Intro.message(for: self) }
}

/// What the slides' miniature screens show: the games of the first and second slide and the game the third slide's
/// room announces. The landing view model fills it, from the live preview when one arrived.
nonisolated struct IntroContent: Equatable, Sendable {
    /// The cards of the Explore miniature.
    let events: [SportEvent]
    /// The game the detail miniature opens; `nil` only when there is no game at all.
    let joinEvent: SportEvent?

    init(events: [SportEvent]) {
        self.events = events
        joinEvent = events.first { !$0.isFull } ?? events.first
    }
}
