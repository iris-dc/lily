import Foundation
import Observation

/// The contact form: a kind, the message, an optional reply email, one send. The backend keeps the item and mails the
/// owner; the sheet thanks the caller. A failure reaches the popup; nothing is retried by itself, because a second send
/// would be a second item, and Send stays available for the caller to repeat.
@Observable
final class FeedbackViewModel {
    var draft: FeedbackDraft
    /// What goes out with the words; the form's footer shows it before the send.
    let environment: FeedbackEnvironment
    private(set) var isSubmitting = false
    private(set) var isSubmitted = false

    private let repository: any FeedbackRepository
    private let errorCenter: ErrorCenter
    private let logger: any Logging

    init(repository: any FeedbackRepository,
         environment: FeedbackEnvironment,
         replyEmail: String?,
         errorCenter: ErrorCenter,
         logger: any Logging) {
        self.repository = repository
        self.environment = environment
        self.draft = FeedbackDraft(replyEmail: replyEmail)
        self.errorCenter = errorCenter
        self.logger = logger
    }

    var canSubmit: Bool {
        draft.isValid && !isSubmitting
    }

    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let receipt = try await repository.send(draft.payload(in: environment))
            isSubmitted = true
            logger.info(.feedback, "Feedback \(receipt.id) sent (\(draft.kind.rawValue))")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.feedback, "Feedback send failed (\(draft.kind.rawValue)): \(error)")
            errorCenter.report(error)
        }
    }
}
