import Foundation
import Testing
@testable import lily

@MainActor
struct RemoteFeedbackRepositoryTests {
    private let client = FakeAPIClient()

    private var repository: RemoteFeedbackRepository { RemoteFeedbackRepository(client: client) }

    @Test func sendPostsTheBodyToTheFeedbackRoute() async throws {
        let receipt = FeedbackReceipt(id: "f1", createdAt: .now)
        client.responses = [receipt]
        let payload = FeedbackDraft(kind: .contact, message: "Hi", replyEmail: "jane@example.com").payload(in: .fixture)

        #expect(try await repository.send(payload) == receipt)
        let request = try #require(client.requests.first)
        #expect(request.method == .post && request.path == "/api/feedback" && request.queryItems.isEmpty)
        #expect(request.body as? FeedbackPayload == payload)
    }

    /// A failure with no case of its own takes the route's fallback; the shared mapping is proved once, in
    /// `SendFailingWithTests`.
    @Test func failuresWithoutACodeBecomeFeedbackFailed() async {
        let payload = FeedbackDraft(message: "Hi").payload(in: .fixture)

        client.error = APIError.http(status: 500, body: nil, retryAfter: nil)
        await #expect(throws: AppError.feedbackFailed) { try await repository.send(payload) }

        client.error = APIError.http(status: 400, body: APIErrorBody(code: "VALIDATION_FAILED", message: "m"), retryAfter: nil)
        await #expect(throws: AppError.feedbackFailed) { try await repository.send(payload) }
    }
}
