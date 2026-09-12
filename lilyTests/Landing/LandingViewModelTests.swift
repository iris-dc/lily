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
