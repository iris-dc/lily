import Foundation
import Testing
@testable import lily

@MainActor
struct LandingViewModelTests {
    private func makeViewModel(_ repository: FakeEventRepository, harness: SessionHarness) -> LandingViewModel {
        LandingViewModel(session: harness.controller, repository: repository, logger: harness.logger)
    }

    @Test func previewIsLimitedToConfiguredCount() async {
        let harness = SessionHarness()
        let repository = FakeEventRepository()
        repository.result = .success(MockEventFixtures.make(now: .now, count: 8))
        let viewModel = makeViewModel(repository, harness: harness)

        await viewModel.loadPreview()

        #expect(viewModel.previewEvents.count == AppConfig.Events.landingPreviewCount)
        #expect(repository.requestedScopes == [.upcoming])
    }

    @Test func previewFailureIsSilentButLogged() async {
        let harness = SessionHarness()
        let repository = FakeEventRepository()
        repository.result = .failure(.network)
        let viewModel = makeViewModel(repository, harness: harness)

        await viewModel.loadPreview()

        #expect(viewModel.previewEvents.isEmpty)
        #expect(harness.errorCenter.current == nil)
        #expect(harness.logger.messages(in: .events, at: .warning).contains { $0.contains("preview") })
    }

    /// Entering the app before the preview arrived cancels its load: the normal flow, never a warning.
    @Test func cancelledPreviewLoadIsADebugLine() async {
        for cancellation: any Error in [URLError(.cancelled), CancellationError()] {
            let harness = SessionHarness()
            let repository = FakeEventRepository()
            repository.thrownError = cancellation
            let viewModel = makeViewModel(repository, harness: harness)

            await viewModel.loadPreview()

            #expect(viewModel.previewEvents.isEmpty)
            #expect(harness.logger.messages(in: .events, at: .warning).isEmpty)
            #expect(harness.logger.messages(in: .events, at: .debug).contains { $0.contains("cancelled") })
        }
    }

    /// The miniatures draw the samples until the preview answered, and the live games from then on.
    @Test func theIntroContentFollowsThePreview() async {
        let harness = SessionHarness()
        let repository = FakeEventRepository()
        let live = MockEventFixtures.make(now: .now, count: 2)
        repository.result = .success(live)
        let viewModel = makeViewModel(repository, harness: harness)

        #expect(viewModel.introContent.events == viewModel.sampleEvents)
        #expect(viewModel.sampleEvents.count == IntroFixtures.eventCount)

        await viewModel.loadPreview()

        #expect(viewModel.introContent.events == live)
    }

    @Test func aFailedPreviewKeepsTheSamplesOnTheSlides() async {
        let harness = SessionHarness()
        let repository = FakeEventRepository()
        repository.result = .failure(.network)
        let viewModel = makeViewModel(repository, harness: harness)

        await viewModel.loadPreview()

        #expect(viewModel.introContent.events == viewModel.sampleEvents)
    }

    @Test func theIntroStartsOnTheFirstSlideWithTheHint() {
        let viewModel = makeViewModel(FakeEventRepository(), harness: SessionHarness())
        #expect(viewModel.slides == IntroSlide.allCases)
        #expect(viewModel.currentSlide == .first)
        #expect(viewModel.showsSwipeHint)
    }

    @Test func showingAnotherSlideHidesTheHintAndLogsIt() {
        let harness = SessionHarness()
        let viewModel = makeViewModel(FakeEventRepository(), harness: harness)

        viewModel.slideShown(.join)

        #expect(viewModel.currentSlide == .join)
        #expect(!viewModel.showsSwipeHint)
        #expect(harness.logger.messages(in: .ui, at: .debug).contains { $0.contains("join") })

        viewModel.slideShown(.discover)

        #expect(viewModel.currentSlide == .discover)
        #expect(!viewModel.showsSwipeHint, "the hint is for the first swipe only")
    }

    /// The pager reports `nil` while a swipe is in flight and the first slide again after a rebound; neither is a
    /// swipe, so the hint stays and nothing is logged.
    @Test func aPositionInFlightOrTheSameSlideChangesNothing() {
        let harness = SessionHarness()
        let viewModel = makeViewModel(FakeEventRepository(), harness: harness)

        viewModel.slideShown(nil)
        viewModel.slideShown(.first)

        #expect(viewModel.currentSlide == .first)
        #expect(viewModel.showsSwipeHint)
        #expect(harness.logger.messages(in: .ui).isEmpty)
    }

    @Test func enterAppUsesGuestMode() {
        let harness = SessionHarness()
        makeViewModel(FakeEventRepository(), harness: harness).enterApp()
        #expect(harness.controller.state == .guest)
    }

    @Test func presentSignInTogglesSheet() {
        let harness = SessionHarness()
        let viewModel = makeViewModel(FakeEventRepository(), harness: harness)
        viewModel.presentSignIn()
        #expect(viewModel.isSignInPresented)
    }
}
