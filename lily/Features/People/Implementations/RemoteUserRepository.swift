import Foundation

/// People from the Laurel backend. Failures arrive as `AppError`, ready for the popup.
final class RemoteUserRepository: UserRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    func profile(userID: String) async throws -> UserProfile {
        try await client.send(.get(AppConfig.API.Paths.user(id: userID)), failingWith: .profileUnavailable)
    }

    func startConversation(with userID: String) async throws -> SportGroup {
        let request = APIRequest<SportGroup>.post(AppConfig.API.Paths.conversations,
                                                  body: StartConversationPayload(userId: userID))
        return try await client.send(request, failingWith: .conversationFailed)
    }
}
