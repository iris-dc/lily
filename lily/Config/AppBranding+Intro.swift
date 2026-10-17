import Foundation

/// Copy of the intro pager on the landing: a headline pair per slide (the miniature says the rest), the lines of the
/// chat miniature and the swipe hint. Plain statements of what the app does, no slogans. In its own file because
/// `AppBranding` is at SwiftLint's type-body limit.
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
