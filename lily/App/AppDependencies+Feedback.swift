import Foundation

extension AppDependencies {
    /// The contact form. The environment is read when the sheet opens, so the footer names the language and version
    /// of that moment, and the reply email starts as the account's.
    func makeFeedbackViewModel() -> FeedbackViewModel {
        FeedbackViewModel(repository: feedbackRepository,
                          environment: .current(languageCode: language.language.code),
                          replyEmail: sessionController.state.user?.email,
                          errorCenter: errorCenter,
                          logger: logger)
    }
}
