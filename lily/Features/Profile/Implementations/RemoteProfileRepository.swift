import Foundation

final class RemoteProfileRepository: ProfileRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    func syncDisplayName(_ name: String) async throws {
        let request = APIRequest<Profile>.put(AppConfig.API.Paths.profile, body: ProfileUpdateRequest(displayName: name))
        _ = try await client.send(request)
    }
}
