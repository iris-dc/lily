import Foundation

/// Copy of the intro pager on the landing: a headline pair and a message per slide, the lines of the chat miniature
/// and the swipe hint. In its own file because `AppBranding` is at SwiftLint's type-body limit.
nonisolated extension AppBranding {
    enum Intro {
        /// Two short lines; the slide draws the second in the accent colour.
        static func headline(for slide: IntroSlide) -> [String] {
            switch slide {
            case .discover: [localized("Real games near you."), localized("Play tonight.")]
            case .join: [localized("Pick a sport."), localized("Join in one tap.")]
            case .create: [localized("Start your own."), localized("Bring your people.")]
            }
        }

        static func message(for slide: IntroSlide) -> String {
            switch slide {
            case .discover: localized("Football, padel, running and more, set up by people like you.")
            case .join: localized("Filter by sport, distance and time. Tap Join and you're in, chat included.")
            case .create: localized("Host a game, build a group with its own chat, or run a whole tournament.")
            }
        }

        /// Under the first slide's caption until the user has swiped once.
        static var swipeHint: String { localized("Swipe up") }

        /// The lines of the room the third slide shows: a member asks, the caller answers, the game is created and the
        /// member closes.
        enum Chat {
            static var question: String { localized("Anyone up for Thursday evening?") }
            static var answer: String { localized("Count me in, I'll bring the bibs.") }
            static var followUp: String { localized("See you at the pitch at 7!") }
        }
    }
}
