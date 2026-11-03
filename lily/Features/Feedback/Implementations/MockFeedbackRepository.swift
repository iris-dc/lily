import Foundation

/// Accepts every message, so previews, UI tests and `-mock-events` runs never need a backend. `sent` is kept so
/// `AppDependenciesFeedbackTests` can prove the view model is wired to the dependencies' own repository.
final class MockFeedbackRepository: FeedbackRepository {
    private(set) var sent: [FeedbackPayload] = []
    private let logger: any Logging
    private let now: () -> Date

    init(logger: any Logging, now: @escaping () -> Date = { .now }) {
        self.logger = logger
        self.now = now
    }

    func send(_ feedback: FeedbackPayload) async throws -> FeedbackReceipt {
        sent.append(feedback)
        logger.info(.feedback, "Mock feedback accepted (\(feedback.kind.rawValue))")
        return FeedbackReceipt(id: UUID().uuidString.lowercased(), createdAt: now())
    }
}
