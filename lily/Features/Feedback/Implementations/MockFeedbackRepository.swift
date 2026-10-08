import Foundation

/// Accepts every message, so previews, UI tests and `-mock-events` runs never need a backend; keeps what was sent for
/// the run, like the other mocks keep their writes.
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
