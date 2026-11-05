import Foundation
import Testing
@testable import lily

@MainActor
struct RemoteProfileRepositoryTests {
    private let client = FakeAPIClient()

    private var repository: RemoteProfileRepository { RemoteProfileRepository(client: client) }

    @Test func profileGetsTheProfileRoute() async throws {
        let profile = try ContractSamples.decode(Profile.self, from: ContractSamples.profile())
        client.responses = [profile]

        let answer = try await repository.profile()

        #expect(answer == profile && profile.userId == "u-1" && profile.displayName == "Apple Tester")
        let request = try #require(client.requests.first)
        #expect(request.method == .get && request.path == "/api/profile" && request.queryItems.isEmpty)
        #expect(request.body == nil)
    }

    @Test func updateDisplayNamePutsTheBodyToTheProfileRoute() async throws {
        let answer = Profile.fixture(displayName: "Alex Kim")
        client.responses = [answer]

        let updated = try await repository.updateDisplayName("Alex Kim")

        #expect(updated == answer)
        let request = try #require(client.requests.first)
        #expect(request.method == .put && request.path == "/api/profile")
        #expect(request.body as? ProfileUpdateRequest == ProfileUpdateRequest(displayName: "Alex Kim"))
        let json = try ContractSamples.jsonObject(of: ProfileUpdateRequest(displayName: "Alex Kim"), as: String.self)
        #expect(json == ["displayName": "Alex Kim"], "the bio is left out, never sent as null")
    }

    /// The bio travels alone, a blank included (it clears); the answer is the profile with the bio as stored.
    @Test func updateBioPutsTheBioAloneToTheProfileRoute() async throws {
        let answer = Profile.fixture(displayName: "Alex Kim", bio: "Padel on Sundays.")
        client.responses = [answer]

        let updated = try await repository.updateBio("Padel on Sundays.")

        #expect(updated == answer)
        let request = try #require(client.requests.first)
        #expect(request.method == .put && request.path == "/api/profile")
        let json = try ContractSamples.jsonObject(of: ProfileUpdateRequest(bio: "Padel on Sundays."), as: String.self)
        #expect(json == ["bio": "Padel on Sundays."], "the name is left out, never sent as null")
        let blank = try ContractSamples.jsonObject(of: ProfileUpdateRequest(bio: ""), as: String.self)
        #expect(blank == ["bio": ""])
    }

    /// The contract's profile with and without a bio.
    @Test func theContractProfileDecodesWithAndWithoutABio() throws {
        let bare = try ContractSamples.decode(Profile.self, from: ContractSamples.profile())
        #expect(bare.bio == nil)
        let written = try ContractSamples.decode(Profile.self, from: ContractSamples.profile(bio: "Padel on Sundays."))
        #expect(written.bio == "Padel on Sundays." && written.displayName == "Apple Tester")
    }

    /// The callers log and show what they catch, so it must be a clean `AppError`: a transport failure stays `.network`,
    /// a codeless failure becomes the route's own case, a backend code its case.
    @Test func failuresWithoutACodeMapToTheRoutesOwnCases() async {
        client.error = URLError(.notConnectedToInternet)
        await #expect(throws: AppError.network) { try await repository.profile() }

        client.error = APIError.http(status: 500, body: nil, retryAfter: nil)
        await #expect(throws: AppError.profileUnavailable) { try await repository.profile() }
        await #expect(throws: AppError.profileUpdateFailed) { try await repository.updateDisplayName("Alex") }
        await #expect(throws: AppError.aboutUpdateFailed) { try await repository.updateBio("Padel") }

        client.error = APIError.http(status: 400, body: APIErrorBody(code: "CONTENT_REJECTED", message: "m"), retryAfter: nil)
        await #expect(throws: AppError.contentRejected) { try await repository.updateDisplayName("x") }
        await #expect(throws: AppError.contentRejected) { try await repository.updateBio("x") }
    }
}
