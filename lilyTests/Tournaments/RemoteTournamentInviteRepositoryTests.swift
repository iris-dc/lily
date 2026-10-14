import Testing
@testable import lily

@MainActor
struct RemoteTournamentInviteRepositoryTests {
    /// The two entry codes this route re-reads as invite refusals, and its fallback: the shared mapping is proved
    /// once, in `SendFailingWithTests` and `BackendErrorCodeTests.everyCodeMapsToItsCase`.
    nonisolated private static let codeCases: [(code: String, expected: AppError)] = [
        ("ALREADY_ENTERED", .inviteeAlreadyEntered), ("FORBIDDEN", .cannotInviteToTournament),
        ("VALIDATION_FAILED", .inviteUnavailable),
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

    @Test func otherFailuresBecomeInviteUnavailable() async {
        client.error = APIError.http(status: 500, body: nil)

        await #expect(throws: AppError.inviteUnavailable) { try await repository.candidates(groupID: "t1") }
        await #expect(throws: AppError.inviteUnavailable) { try await repository.invite(groupID: "t1", userID: "sub-2") }
    }
}
