import Foundation
import Testing
@testable import lily

@MainActor
struct RemoteMeRepositoryTests {
    private let client = FakeAPIClient()

    private var repository: RemoteMeRepository { RemoteMeRepository(client: client) }

    @Test func meGetsTheMeResource() async throws {
        let account = Account.fixture()
        client.responses = [account]

        #expect(try await repository.me() == account)
        let request = try #require(client.requests.first)
        #expect(request.method == .get && request.path == "/api/me" && request.body == nil && request.queryItems.isEmpty)
    }

    @Test func acceptTermsPutsTheVersion() async throws {
        let acceptance = TermsAcceptance(acceptedTermsVersion: 2, acceptedTermsAt: .now)
        client.responses = [acceptance]

        #expect(try await repository.acceptTerms(version: 2) == acceptance)
        let request = try #require(client.requests.first)
        #expect(request.method == .put && request.path == "/api/me/terms")
        #expect(request.body as? TermsAcceptancePayload == TermsAcceptancePayload(version: 2))
    }

    @Test func failuresKeepTheSharedMappingAndFallBackToUnknown() async {
        client.error = APIError.http(status: 401, body: nil)
        await #expect(throws: AppError.sessionExpired) { try await repository.me() }

        client.error = APIError.http(status: 400, body: APIErrorBody(code: "VALIDATION_FAILED", message: "m"))
        await #expect(throws: AppError.unknown) { try await repository.acceptTerms(version: 1) }

        client.error = URLError(.notConnectedToInternet)
        await #expect(throws: AppError.network) { try await repository.me() }
    }
}
