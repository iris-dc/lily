import Foundation

/// Messages to us: questions, feedback and bug reports. One send is one stored item; nothing is replayed.
protocol FeedbackRepository {
    func send(_ feedback: FeedbackPayload) async throws -> FeedbackReceipt
}
