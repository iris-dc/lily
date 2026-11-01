import Foundation

final class RemoteProfileRepository: ProfileRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    func profile() async throws -> Profile {
        try await client.send(APIRequest<Profile>.get(AppConfig.API.Paths.profile), failingWith: .profileUnavailable)
    }

    func updateDisplayName(_ name: String) async throws -> Profile {
        let request = APIRequest<Profile>.put(AppConfig.API.Paths.profile, body: ProfileUpdateRequest(displayName: name))
        return try await client.send(request, failingWith: .profileUpdateFailed)
    }
}
