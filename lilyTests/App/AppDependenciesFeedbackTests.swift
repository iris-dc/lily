import Foundation
import Testing
@testable import lily

/// The contact form's wiring per launch argument; the main suite is at its type-body limit.
@MainActor
struct AppDependenciesFeedbackTests {
    @Test func mockEventsSelectTheMockFeedbackRepositoryAndTheDefaultTheRemoteOne() {
        let mocked = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents], defaults: makeTestDefaults())
        #expect(mocked.feedbackRepository is MockFeedbackRepository)
        #expect(AppDependencies.makeMock().feedbackRepository is MockFeedbackRepository)

        let remote = AppDependencies.makeDefault(arguments: [], defaults: makeTestDefaults())
        #expect(remote.feedbackRepository is RemoteFeedbackRepository)
    }

    /// The sheet opens with the account's email and the language of the moment; the mock accepts the send.
    @Test func theFormStartsFromTheAccountAndTheLanguageAndTheMockAccepts() async throws {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                                   AppConfig.LaunchArguments.mockAuth,
                                                                   AppConfig.LaunchArguments.mockEvents],
                                                       defaults: makeTestDefaults())
        await dependencies.sessionController.signIn(with: .apple)
        let email = try #require(dependencies.sessionController.state.user?.email)

        let viewModel = dependencies.makeFeedbackViewModel()
        #expect(viewModel.draft.replyEmail == email)
        #expect(viewModel.environment.locale == dependencies.language.language.code)
        #expect(!viewModel.environment.appVersion.isEmpty && viewModel.environment.osVersion.hasPrefix("iOS "))

        viewModel.draft.message = "Hello"
        await viewModel.submit()
        #expect(viewModel.isSubmitted)
        let mock = try #require(dependencies.feedbackRepository as? MockFeedbackRepository)
        #expect(mock.sent.map(\.message) == ["Hello"])
    }
}
