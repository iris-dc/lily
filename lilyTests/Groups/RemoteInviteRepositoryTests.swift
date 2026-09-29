import Foundation
import Testing
@testable import lily

@MainActor
struct RemoteInviteRepositoryTests {
    /// `nonisolated`: `@Test(arguments:)` reads it off the main actor.
    nonisolated private static let codeCases: [(code: String, expected: AppError)] = [
        ("NOT_A_MEMBER", .notAMember), ("FORBIDDEN", .insufficientRole), ("GROUP_NOT_FOUND", .groupNotFound),
        ("USER_NOT_FOUND", .userNotFound), ("ALREADY_MEMBER", .alreadyMember), ("CANNOT_INVITE", .cannotInvite),
        ("TERMS_REQUIRED", .termsRequired), ("RATE_LIMITED", .rateLimited(retryAfter: nil)), ("TRY_AGAIN", .tryAgain),
        ("VALIDATION_FAILED", .inviteUnavailable),
    ]
    private static let otherFailures: [APIError] = [
        .http(status: 500, body: nil), .http(status: 403, body: nil), .decodingFailed, .notHTTPResponse,
    ]

    private let client = FakeAPIClient()
    private let candidate = InviteCandidate.fixture()

    private var repository: RemoteInviteRepository { RemoteInviteRepository(client: client) }

    @Test func candidatesGetTheInviteesAndUnwrapTheItems() async throws {
        client.responses = [Page(items: [candidate])]

        #expect(try await repository.candidates(groupID: "g1") == [candidate])
        let request = try #require(client.requests.first)
        #expect(request.method == .get && request.path == "/api/groups/g1/invitees")
        #expect(request.body == nil && request.queryItems.isEmpty)
    }

    @Test func invitePostsTheUserIdToTheGroupsInvites() async throws {
        let sent = SentInvite.fixture(groupID: "g1")
        client.responses = [sent]

        #expect(try await repository.invite(groupID: "g1", userID: "u-2") == sent)
        let request = try #require(client.requests.first)
        #expect(request.method == .post && request.path == "/api/groups/g1/invites")
        #expect(request.body as? SendInvitePayload == SendInvitePayload(userId: "u-2"))
    }

    @Test func theContractShapesDecode() throws {
        let page = try ContractSamples.decode(Page<InviteCandidate>.self, from: ContractSamples.inviteCandidates)
        #expect(page.items.map(\.displayName) == ["Marta", "Noor"] && page.nextCursor == nil)
        let marta = InviteCandidate(userId: "seed-marta", displayName: "Marta", via: .group, viaName: "Kreuzberg Kickers")
        #expect(page.items[0] == marta)
        #expect(page.items[1].via == .event && page.items[1].viaName == "Sunset 5-a-side" && page.items[1].isInvited)

        let sent = try ContractSamples.decode(SentInvite.self, from: ContractSamples.sentInvite)
        #expect(sent.id == "01J9B4X6KQ2M8N0P3R5T7V9W1Y" && sent.groupId == "7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d")
        #expect(sent.inviteeUserId == "seed-marta" && sent.inviteeName == "Marta" && sent.status == .pending)
        #expect(sent.createdAt == APIJSONCoding.parseInstant("2026-09-29T10:00:00Z"))
        #expect(sent.expiresAt == APIJSONCoding.parseInstant("2026-10-06T10:00:00Z"))
    }

    @Test func thePayloadEncodesTheUserIdAlone() throws {
        let data = try APIJSONCoding.makeEncoder().encode(SendInvitePayload(userId: "u-2"))
        #expect(String(bytes: data, encoding: .utf8) == #"{"userId":"u-2"}"#)
    }

    @Test(arguments: codeCases)
    func backendCodesMapToAppErrors(code: String, expected: AppError) async {
        client.error = APIError.http(status: 409, body: APIErrorBody(code: code, message: "m"))

        await #expect(throws: expected) { try await repository.candidates(groupID: "g1") }
        await #expect(throws: expected) { try await repository.invite(groupID: "g1", userID: "u-2") }
    }

    @Test func otherFailuresBecomeInviteUnavailable() async {
        for error in Self.otherFailures {
            client.error = error
            await #expect(throws: AppError.inviteUnavailable) { try await repository.candidates(groupID: "g1") }
            await #expect(throws: AppError.inviteUnavailable) { try await repository.invite(groupID: "g1", userID: "u-2") }
        }
    }

    @Test func statusOnlyFailuresAndTransportKeepTheSharedMapping() async {
        client.error = APIError.http(status: 401, body: nil)
        await #expect(throws: AppError.sessionExpired) { try await repository.candidates(groupID: "g1") }

        client.error = APIError.http(status: 429, body: nil)
        await #expect(throws: AppError.rateLimited(retryAfter: nil)) { try await repository.invite(groupID: "g1", userID: "u-2") }

        client.error = URLError(.notConnectedToInternet)
        await #expect(throws: AppError.network) { try await repository.invite(groupID: "g1", userID: "u-2") }

        client.error = URLError(.cancelled)
        await #expect(throws: URLError(.cancelled)) { try await repository.candidates(groupID: "g1") }
    }
}
