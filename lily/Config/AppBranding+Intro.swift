import Foundation

/// Copy of the intro pager on the landing: a headline pair and a message per slide, the lines of the chat miniature
/// and the swipe hint. Plain statements of what the app does, no slogans. In its own file because `AppBranding` is at
/// SwiftLint's type-body limit.
nonisolated extension AppBranding {
    enum Intro {
        /// Two short lines that read as one sentence; the slide draws the second in the accent colour.
        static func headline(for slide: IntroSlide) -> [String] {
            switch slide {
            case .events: [localized("Find sports events"), localized("near you.")]
            case .join: [localized("Join an event"), localized("in one tap.")]
            case .groups: [localized("Join a group"), localized("or start one.")]
            case .tournaments: [localized("Enter a tournament"), localized("or set one up.")]
            }
        }

        static func message(for slide: IntroSlide) -> String {
            switch slide {
            case .events:
                localized("""
                Football, running, padel, yoga and more, set up by people around you. \
                Filter by sport, distance and date, or create your own.
                """)
            case .join:
                localized("See the time, the place, the host and how many have joined. Tap Join and you're in.")
            case .groups:
                localized("""
                Groups for a sport or a place, public or invite-only, each with its own chat. \
                Members create events together.
                """)
            case .tournaments:
                localized("""
                Knockout or round robin, solo or in teams. \
                Players report results, and the bracket or standings update for everyone.
                """)
            }
        }

        /// Under the first slide's caption until the user has swiped once.
        static var swipeHint: String { localized("Swipe up") }

        /// The lines of the room the groups slide shows: a member asks, the caller answers, the game is created and the
        /// member closes.
        enum Chat {
            static var question: String { localized("Anyone up for Thursday evening?") }
            static var answer: String { localized("Count me in, I'll bring the bibs.") }
            static var followUp: String { localized("See you at the pitch at 7!") }
        }
    }
}
