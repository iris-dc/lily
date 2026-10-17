import Foundation

/// The intro's pages in swipe order, one headline each: the events to find, how to join one, the groups, the
/// tournaments. Groups and tournaments show only while their features are on, so the intro never promises a screen the
/// build has no way to; the groups slide shows a room and speaks of the chat, so it needs the chat as well.
nonisolated enum IntroSlide: String, CaseIterable, Identifiable, Sendable {
    case events, join, groups, tournaments

    static let first: IntroSlide = .events

    /// The slides this build shows, in swipe order; the flags default to the build's.
    static func shown(groups: Bool = AppConfig.FeatureFlags.groups && AppConfig.FeatureFlags.chat,
                      tournaments: Bool = AppConfig.FeatureFlags.tournaments) -> [IntroSlide] {
        allCases.filter { slide in
            switch slide {
            case .events, .join: true
            case .groups: groups
            case .tournaments: tournaments
            }
        }
    }

    var id: String { rawValue }

    /// Two short lines, the whole of a slide's caption; the slide draws the second in the accent colour.
    var headline: [String] { AppBranding.Intro.headline(for: self) }

    /// Whether the miniature's last control is the point (the detail's Join, the room's composer), so a frame too short
    /// for the screen keeps its bottom and crops the top; the list and the bracket keep their top and fade out below,
    /// where the screen goes on.
    var keepsBottom: Bool {
        switch self {
        case .join, .groups: true
        case .events, .tournaments: false
        }
    }
}

/// What the slides' miniature screens show: the events of the first slide, the one the second slide's detail opens
/// (its title is also the game the group room announces), and the tournament whose bracket the last slide draws. The
/// landing view model fills the events from the live preview when one arrived; the tournament is always the fixture,
/// since a live one may be in any state and the slide is about the bracket.
nonisolated struct IntroContent: Equatable, Sendable {
    /// The cards of the Explore miniature.
    let events: [SportEvent]
    /// The event the detail miniature opens; `nil` only when there is no event at all.
    let joinEvent: SportEvent?
    /// A tournament under way, with results in.
    let tournament: TournamentDetail

    init(events: [SportEvent], tournament: TournamentDetail) {
        self.events = events
        joinEvent = events.first { !$0.isFull } ?? events.first
        self.tournament = tournament
    }
}
