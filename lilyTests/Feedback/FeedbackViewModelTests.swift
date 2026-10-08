import Foundation
import Testing
@testable import lily

/// The contact form's model: the email starts as the account's, nothing goes out invalid, a send answers the thanks
/// state, a failure the popup, a cancellation nothing.
@MainActor
struct FeedbackViewModelTests {
    private let repository = FakeFeedbackRepository()
    private let logger = SpyLogger()
    private let errorCenter: ErrorCenter

    init() {
        errorCenter = ErrorCenter(logger: logger)
    }

    private func makeViewModel(replyEmail: String? = "jane@example.com") -> FeedbackViewModel {
        FeedbackViewModel(repository: repository,
                          environment: .fixture,
                          replyEmail: replyEmail,
                          errorCenter: errorCenter,
                          logger: logger)
    }

    @Test func theEmailIsPrefilledAndTheMessageIsNeeded() async {
        let viewModel = makeViewModel()
        #expect(viewModel.draft.replyEmail == "jane@example.com" && !viewModel.canSubmit)
        #expect(makeViewModel(replyEmail: nil).draft.replyEmail.isEmpty)

        await viewModel.submit()
        #expect(repository.sent.isEmpty && !viewModel.isSubmitted)
    }

    @Test func aSendCarriesTheDraftAndTheEnvironmentAndThanks() async {
        let viewModel = makeViewModel()
        viewModel.draft.kind = .bug
        viewModel.draft.message = "  The map shows no pins.  "
        #expect(viewModel.canSubmit)

        await viewModel.submit()

        let sent = repository.sent.first
        #expect(sent?.kind == .bug && sent?.message == "The map shows no pins." && sent?.replyEmail == "jane@example.com")
        #expect(sent?.appVersion == "1.0 (42)" && sent?.osVersion == "iOS 26.0.1" && sent?.device == "iPhone17,1")
        #expect(sent?.locale == "en")
        #expect(viewModel.isSubmitted && !viewModel.isSubmitting && errorCenter.current == nil)
        #expect(logger.messages(in: .feedback, at: .info) == ["Feedback f-1 sent (bug)"])
    }

    @Test func aFailureReachesThePopupAndKeepsTheDraft() async {
        let viewModel = makeViewModel()
        viewModel.draft.message = "Hello"
        repository.error = AppError.feedbackFailed

        await viewModel.submit()

        #expect(errorCenter.current?.error == .feedbackFailed && !viewModel.isSubmitted)
        #expect(viewModel.draft.message == "Hello" && viewModel.canSubmit, "Send stays available for a repeat")
        #expect(logger.messages(in: .feedback, at: .error) == ["Feedback send failed (feedback): feedbackFailed"])
    }

    @Test func aCancelledSendStaysQuiet() async {
        let viewModel = makeViewModel()
        viewModel.draft.message = "Hello"
        repository.error = CancellationError()

        await viewModel.submit()

        #expect(errorCenter.current == nil && !viewModel.isSubmitted && logger.messages(in: .feedback).isEmpty)
    }

    @Test func aSecondSubmitWhileOneIsInFlightIsDropped() async {
        let viewModel = makeViewModel()
        viewModel.draft.message = "Hello"
        repository.holdsRequests = true

        let first = Task { await viewModel.submit() }
        await settle(until: { viewModel.isSubmitting })
        #expect(!viewModel.canSubmit)
        await viewModel.submit()
        #expect(repository.sent.count == 1, "the repeat is dropped rather than filed as a second item")

        repository.releaseRequests()
        await first.value
        #expect(viewModel.isSubmitted && !viewModel.isSubmitting)
    }

    @Test func anInvalidEmailHoldsTheSend() {
        let viewModel = makeViewModel(replyEmail: "jane@")
        viewModel.draft.message = "Hello"
        #expect(!viewModel.canSubmit)
        viewModel.draft.replyEmail = ""
        #expect(viewModel.canSubmit)
    }
}
