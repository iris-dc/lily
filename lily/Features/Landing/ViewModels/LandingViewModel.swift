import Foundation
import Observation

/// Drives the landing screen: the intro slides, the games their miniature screens show (real upcoming ones once the
/// preview arrived), and the two ways into the app.
@Observable
final class LandingViewModel {
    let slides = IntroSlide.allCases
    private(set) var previewEvents: [SportEvent] = []
    /// The games the miniatures show until the live preview arrives: the mock feed's first ones, like a screenshot.
    let sampleEvents: [SportEvent]
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
    }

    /// What the slides' screens draw: the live games once loaded, the samples before and when the load failed.
    var introContent: IntroContent {
        IntroContent(events: previewEvents.isEmpty ? sampleEvents : previewEvents)
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
