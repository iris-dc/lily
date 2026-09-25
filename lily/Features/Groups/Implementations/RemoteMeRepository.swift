import Foundation

final class RemoteMeRepository: MeRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    func me() async throws -> Account {
        try await client.send(.get(AppConfig.API.Paths.me), failingWith: .unknown)
    }

    func acceptTerms(version: Int) async throws -> TermsAcceptance {
        let request = APIRequest<TermsAcceptance>.put(AppConfig.API.Paths.meTerms, body: TermsAcceptancePayload(version: version))
        return try await client.send(request, failingWith: .unknown)
    }
}
