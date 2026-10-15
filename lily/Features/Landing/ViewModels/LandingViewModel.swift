import Foundation
import Observation

/// Drives the landing screen: the intro slides, the events their miniature screens show (real upcoming ones once the
/// preview arrived), the tournament whose bracket the last slide draws, and the two ways into the app.
@Observable
final class LandingViewModel {
    let slides = IntroSlide.shown()
    private(set) var previewEvents: [SportEvent] = []
    /// The events the miniatures show until the live preview arrives: the mock feed's first ones, like a screenshot.
    let sampleEvents: [SportEvent]
    /// The tournament the bracket miniature shows: always the fixture, since a live one may be in any state.
    let sampleTournament: TournamentDetail
    /// The slide on screen, as the pager last reported one.
    private(set) var currentSlide: IntroSlide = .first
    /// "Swipe up" shows under the first slide until the user has swiped once.
    private(set) var showsSwipeHint = true
    var isSignInPresented = false

    private let session: SessionController
    private let repository: any EventRepository
    private let logger: any Logging

    init(session: SessionController, repository: any EventRepository, logger: any Logging, now: Date = .now) {
        self.session = session
        self.repository = repository
        self.logger = logger
        sampleEvents = IntroFixtures.events(now: now)
        sampleTournament = IntroFixtures.tournament(now: now)
    }

    /// What the slides' screens draw: the live events once loaded, the samples before and when the load failed.
    var introContent: IntroContent {
        IntroContent(events: previewEvents.isEmpty ? sampleEvents : previewEvents, tournament: sampleTournament)
    }

    /// Preview is decorative: on failure the landing still works, so nothing is shown to the user. Leaving the
    /// landing mid-load cancels the request, which is not a failure and stays at debug.
    func loadPreview() async {
        do {
            let events = try await repository.events(in: .upcoming, near: nil)
            previewEvents = Array(events.prefix(AppConfig.Events.landingPreviewCount))
        } catch {
            guard !AppError.isCancellation(error) else {
                logger.debug(.events, "Landing preview load cancelled")
                return
            }
            logger.warning(.events, "Landing preview unavailable: \(error)")
        }
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
