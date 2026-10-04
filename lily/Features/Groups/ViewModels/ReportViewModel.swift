import Foundation
import Observation

/// The report sheet: a reason, an optional comment, one send. What is reported is fixed when the sheet opens (a
/// tournament, in time a group or a message); the backend keeps the report and answers a receipt, and the sheet thanks
/// the caller. Failures reach the popup through the reporter; nothing is retried, a repeat on the same target answers
/// the same report.
@Observable
final class ReportViewModel {
    let target: ReportTarget
    /// The sheet's title, naming what is reported ("Report tournament").
    let title: String
    var reason: ReportReason?
    var comment = ""
    private(set) var isSubmitting = false
    private(set) var isSubmitted = false

    private let repository: any ModerationRepository
    private let reporter: GroupErrorReporter
    private let logger: any Logging

    init(target: ReportTarget,
         title: String,
         repository: any ModerationRepository,
         reporter: GroupErrorReporter,
         logger: any Logging) {
        self.target = target
        self.title = title
        self.repository = repository
        self.reporter = reporter
        self.logger = logger
    }

    /// A reason picked, a comment within the backend's limit, nothing in flight.
    var canSubmit: Bool {
        reason != nil && !isSubmitting && comment.wireLength <= AppConfig.Moderation.commentMaxLength
    }

    func submit() async {
        guard let reason, canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let receipt = try await repository.report(ReportPayload(target: target, reason: reason, comment: comment))
            isSubmitted = true
            logger.info(target.logCategory, "Report \(receipt.id) filed on \(target.kind.rawValue) \(target.id)")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(target.logCategory, "Report on \(target.kind.rawValue) \(target.id) failed: \(error)")
            reporter.report(error)
        }
    }
}
