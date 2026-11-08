import Foundation

final class RemoteMeRepository: MeRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    func me() async throws -> Account {
        try await client.send(.get(AppConfig.API.Paths.me), failingWith: .unknown)
    }

    func deletionPlan() async throws -> DeletionPlan {
        try await client.send(.get(AppConfig.API.Paths.meDeletionPlan), failingWith: .deletionPlanUnavailable)
    }

    /// `202 Accepted` with an empty body, replays included; the post-completion 401 maps to `.sessionExpired`.
    func deleteAccount() async throws {
        _ = try await client.send(APIRequest<NoContent>.delete(AppConfig.API.Paths.me), failingWith: .accountDeletionFailed)
    }
}
