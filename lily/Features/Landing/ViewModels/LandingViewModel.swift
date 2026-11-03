import Foundation
import Observation

/// Drives the landing screen: the intro slides, the events and the tournament their miniature screens draw, and the two
/// ways into the app. The miniatures draw fixtures, never a live answer: a screen that changed under the reader a moment
/// after the app opened read as a glitch, and the landing is seen before anything of theirs is known.
@Observable
final class LandingViewModel {
    let slides = IntroSlide.shown()
    /// The events the Explore miniature shows: the mock feed's first ones, like a screenshot.
    let sampleEvents: [SportEvent]
    /// The tournament the bracket miniature shows: the fixture, since a live one may be in any state.
    let sampleTournament: TournamentDetail
    /// The slide on screen, as the pager last reported one.
    private(set) var currentSlide: IntroSlide = .first
    /// "Swipe up" shows under the first slide until the user has swiped once.
    private(set) var showsSwipeHint = true
    var isSignInPresented = false

    private let session: SessionController
    private let logger: any Logging

    init(session: SessionController, logger: any Logging) {
        self.session = session
        self.logger = logger
        let now = Date.now
        sampleEvents = IntroFixtures.events(now: now)
        sampleTournament = IntroFixtures.tournament(now: now)
    }

    /// What the slides' screens draw.
    var introContent: IntroContent {
        IntroContent(events: sampleEvents, tournament: sampleTournament)
    }

    /// The pager's report of the slide at rest: `nil` while a swipe is in flight, and the same slide again after a
    /// rebound, neither of which is a swipe.
    func slideShown(_ slide: IntroSlide?) {
        guard let slide, slide != currentSlide else { return }
        currentSlide = slide
        showsSwipeHint = false
        logger.debug(.ui, "Intro slide \(slide.rawValue) shown")
    }

    func enterApp() { session.continueAsGuest() }
    func presentSignIn() { isSignInPresented = true }
}
