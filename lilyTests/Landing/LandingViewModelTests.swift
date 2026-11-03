import Foundation
import Testing
@testable import lily

@MainActor
struct LandingViewModelTests {
    private func makeViewModel(harness: SessionHarness) -> LandingViewModel {
        LandingViewModel(session: harness.controller, logger: harness.logger)
    }

    /// The miniatures draw the fixtures, dated from launch, and never a live answer: nothing changes under the reader.
    @Test func theIntroContentIsTheFixtures() {
        let viewModel = makeViewModel(harness: SessionHarness())

        #expect(viewModel.introContent.events == viewModel.sampleEvents)
        #expect(viewModel.sampleEvents.count == AppConfig.Events.introSampleEventCount)
        #expect(viewModel.introContent.tournament == viewModel.sampleTournament)
        #expect(viewModel.introContent.joinEvent != nil, "the detail slide has a game to join")
    }

    @Test func theIntroStartsOnTheFirstSlideWithTheHint() {
        let viewModel = makeViewModel(harness: SessionHarness())
        #expect(viewModel.slides == IntroSlide.shown())
        #expect(viewModel.currentSlide == .first)
        #expect(viewModel.showsSwipeHint)
    }

    @Test func showingAnotherSlideHidesTheHintAndLogsIt() {
        let harness = SessionHarness()
        let viewModel = makeViewModel(harness: harness)

        viewModel.slideShown(.join)

        #expect(viewModel.currentSlide == .join)
        #expect(!viewModel.showsSwipeHint)
        #expect(harness.logger.messages(in: .ui, at: .debug).contains { $0.contains("join") })

        viewModel.slideShown(.events)

        #expect(viewModel.currentSlide == .events)
        #expect(!viewModel.showsSwipeHint, "the hint is for the first swipe only")
    }

    /// The pager reports `nil` while a swipe is in flight and the first slide again after a rebound; neither is a
    /// swipe, so the hint stays and nothing is logged.
    @Test func aPositionInFlightOrTheSameSlideChangesNothing() {
        let harness = SessionHarness()
        let viewModel = makeViewModel(harness: harness)

        viewModel.slideShown(nil)
        viewModel.slideShown(.first)

        #expect(viewModel.currentSlide == .first)
        #expect(viewModel.showsSwipeHint)
        #expect(harness.logger.messages(in: .ui).isEmpty)
    }

    @Test func enterAppUsesGuestMode() {
        let harness = SessionHarness()
        makeViewModel(harness: harness).enterApp()
        #expect(harness.controller.state == .guest)
    }

    @Test func presentSignInTogglesSheet() {
        let harness = SessionHarness()
        let viewModel = makeViewModel(harness: harness)
        viewModel.presentSignIn()
        #expect(viewModel.isSignInPresented)
    }
}
