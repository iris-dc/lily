import Foundation
import Testing
@testable import lily

@MainActor
struct RemoteTournamentInviteRepositoryTests {
    /// The entry codes read as invite refusals here; the rest keep their shared mapping.
    nonisolated private static let codeCases: [(code: String, expected: AppError)] = [
        ("ALREADY_ENTERED", .inviteeAlreadyEntered), ("FORBIDDEN", .cannotInviteToTournament),
        ("REGISTRATION_CLOSED", .registrationClosed), ("USER_NOT_FOUND", .userNotFound),
        ("TOURNAMENT_NOT_FOUND", .tournamentNotFound), ("RATE_LIMITED", .rateLimited(retryAfter: nil)),
        ("TERMS_REQUIRED", .termsRequired), ("TRY_AGAIN", .tryAgain), ("VALIDATION_FAILED", .inviteUnavailable),
    ]

    private let client = FakeAPIClient()

    private var repository: RemoteTournamentInviteRepository { RemoteTournamentInviteRepository(client: client) }

    @Test func candidatesAndInvitesUseTheTournamentRoutes() async throws {
        let noor = InviteCandidate.fixture(userId: "sub-2", displayName: "Noor", viaName: "Kickers Cup")
        let sentInvite = SentInvite.fixture(id: "i1", groupID: nil, tournamentID: "t1", inviteeUserId: "sub-2")
        client.responses = [Page<InviteCandidate>(items: [noor]), sentInvite]

        let candidates = try await repository.candidates(groupID: "t1")
        let sent = try await repository.invite(groupID: "t1", userID: "sub-2")

        #expect(candidates == [noor] && sent.tournamentId == "t1" && sent.groupId == nil)
        #expect(client.requests[0].method == .get && client.requests[0].path == "/api/tournaments/t1/invitees")
        #expect(client.requests[1].method == .post && client.requests[1].path == "/api/tournaments/t1/invites")
        #expect(client.requests[1].body as? SendInvitePayload == SendInvitePayload(userId: "sub-2"))
    }

    @Test(arguments: codeCases)
    func backendCodesMapToTheInviteRefusals(code: String, expected: AppError) async {
        client.error = APIError.http(status: 409, body: APIErrorBody(code: code, message: "m"))

        await #expect(throws: expected) { try await repository.candidates(groupID: "t1") }
        await #expect(throws: expected) { try await repository.invite(groupID: "t1", userID: "sub-2") }
    }

    @Test func otherFailuresBecomeInviteUnavailableAndTransportKeepsTheSharedMapping() async {
        client.error = APIError.http(status: 500, body: nil)
        await #expect(throws: AppError.inviteUnavailable) { try await repository.candidates(groupID: "t1") }
        client.error = APIError.http(status: 401, body: nil)
        await #expect(throws: AppError.sessionExpired) { try await repository.invite(groupID: "t1", userID: "sub-2") }
        client.error = URLError(.notConnectedToInternet)
        await #expect(throws: AppError.network) { try await repository.invite(groupID: "t1", userID: "sub-2") }
        client.error = URLError(.cancelled)
        await #expect(throws: URLError(.cancelled)) { try await repository.candidates(groupID: "t1") }
    }
}
