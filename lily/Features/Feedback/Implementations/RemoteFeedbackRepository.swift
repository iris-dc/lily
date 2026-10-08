import Foundation

final class RemoteFeedbackRepository: FeedbackRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    func send(_ feedback: FeedbackPayload) async throws -> FeedbackReceipt {
        let request = APIRequest<FeedbackReceipt>.post(AppConfig.API.Paths.feedback, body: feedback)
        return try await client.send(request, failingWith: .feedbackFailed)
    }
}
