import Testing
@testable import lily

@MainActor
struct RemoteEventInviteRepositoryTests {
    /// The codes this route reads as invite refusals (the event's own `EVENT_STARTED` among them), and one that falls
    /// to its fallback; the rest keep the shared mapping.
    nonisolated private static let codeCases: [(code: String, expected: AppError)] = [
        ("ALREADY_JOINED", .inviteeAlreadyJoined), ("FORBIDDEN", .cannotInviteToEvent),
        ("INVITE_LIMIT", .eventInviteLimit), ("EVENT_STARTED", .eventStarted),
        ("VALIDATION_FAILED", .inviteUnavailable),
    ]

    private let client = FakeAPIClient()

    private var repository: RemoteEventInviteRepository { RemoteEventInviteRepository(client: client) }

    @Test func candidatesAndInvitesUseTheEventRoutes() async throws {
        let noor = InviteCandidate.fixture(userId: "sub-2", displayName: "Noor", viaName: "Kreuzberg Kickers")
        let sentInvite = SentInvite.fixture(id: "i1", groupID: nil, eventID: "e1", inviteeUserId: "sub-2")
        client.responses = [Page<InviteCandidate>(items: [noor]), sentInvite]

        let candidates = try await repository.candidates(groupID: "e1")
        let sent = try await repository.invite(groupID: "e1", userID: "sub-2")

        #expect(candidates == [noor] && sent.eventId == "e1" && sent.groupId == nil && sent.tournamentId == nil)
        #expect(client.requests[0].method == .get && client.requests[0].path == "/api/events/e1/invitees")
        #expect(client.requests[1].method == .post && client.requests[1].path == "/api/events/e1/invites")
        #expect(client.requests[1].body as? SendInvitePayload == SendInvitePayload(userId: "sub-2"))
    }

    @Test(arguments: codeCases)
    func backendCodesMapToTheInviteRefusals(code: String, expected: AppError) async {
        client.error = APIError.http(status: 409, body: APIErrorBody(code: code, message: "m"))

        await #expect(throws: expected) { try await repository.candidates(groupID: "e1") }
        await #expect(throws: expected) { try await repository.invite(groupID: "e1", userID: "sub-2") }
    }

    @Test func otherFailuresBecomeInviteUnavailable() async {
        client.error = APIError.http(status: 500, body: nil)

        await #expect(throws: AppError.inviteUnavailable) { try await repository.candidates(groupID: "e1") }
        await #expect(throws: AppError.inviteUnavailable) { try await repository.invite(groupID: "e1", userID: "sub-2") }
    }
}
