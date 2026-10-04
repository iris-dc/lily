import Foundation
import Testing
@testable import lily

@MainActor
struct RemoteTournamentRepositoryTests {
    nonisolated private static let codeCases: [(code: String, expected: AppError)] = [
        ("TOURNAMENT_NOT_FOUND", .tournamentNotFound), ("TOURNAMENT_ID_TAKEN", .tournamentCreationFailed),
        ("TOURNAMENT_ID_REUSED", .tournamentCreationFailed), ("TOURNAMENT_LIMIT", .tournamentLimit),
        ("NOT_ORGANIZER", .notOrganizer), ("TOURNAMENT_LOCKED", .tournamentLocked), ("REGISTRATION_CLOSED", .registrationClosed),
        ("TOURNAMENT_FULL", .tournamentFull), ("ALREADY_ENTERED", .alreadyEntered), ("TEAM_FULL", .teamFull),
        ("ENTRY_NOT_FOUND", .entryNotFound), ("NOT_ENOUGH_ENTRIES", .notEnoughEntries), ("NOT_IN_MATCH", .notInMatch),
        ("MATCH_NOT_READY", .matchNotReady), ("DRAW_NOT_ALLOWED", .drawNotAllowed), ("CAPACITY_TOO_LOW", .capacityTooLow),
        ("MEMBERSHIP_LIMIT", .membershipLimitReached), ("GROUP_NOT_FOUND", .groupNotFound), ("FORBIDDEN", .insufficientRole),
        ("TRY_AGAIN", .tryAgain), ("TERMS_REQUIRED", .termsRequired), ("VALIDATION_FAILED", .tournamentActionFailed),
    ]

    private let client = FakeAPIClient()
    private let detail = TournamentDetail.fixture()
    private let entry = TournamentEntry.fixture()

    private var repository: RemoteTournamentRepository { RemoteTournamentRepository(client: client) }

    @Test func listsAskForTheirScopeAndThePositionOnExploreOnly() async throws {
        client.responses = [Page<Tournament>(items: [.fixture()]), Page<Tournament>(items: []), Page<Tournament>(items: [])]
        let position = Coordinate(latitude: 52.5234, longitude: 13.4055)

        let upcoming = try await repository.tournaments(in: .upcoming, near: position)
        _ = try await repository.tournaments(in: .mine, near: position)
        _ = try await repository.tournaments(in: .group(id: "g1"), near: position)

        #expect(upcoming.count == 1)
        #expect(client.requests[0].path == "/api/tournaments" && client.requests[0].method == .get)
        #expect(client.requests[0].queryItems == [URLQueryItem(name: "scope", value: "upcoming"),
                                                  URLQueryItem(name: "lat", value: "52.52"),
                                                  URLQueryItem(name: "lon", value: "13.41")])
        #expect(client.requests[1].queryItems == [URLQueryItem(name: "scope", value: "mine")])
        #expect(client.requests[2].path == "/api/groups/g1/tournaments" && client.requests[2].queryItems.isEmpty)
    }

    @Test func detailCreateAndUpdateUseTheirRoutes() async throws {
        client.responses = [detail, detail, detail]
        let draft = TournamentDraft.fixture()

        #expect(try await repository.tournament(id: "t") == detail)
        _ = try await repository.create(draft)
        _ = try await repository.update(id: "t", draft)

        #expect(client.requests[0].method == .get && client.requests[0].path == "/api/tournaments/t")
        #expect(client.requests[1].method == .post && client.requests[1].path == "/api/tournaments")
        #expect(client.requests[1].body as? CreateTournamentPayload == CreateTournamentPayload(draft: draft))
        #expect(client.requests[2].method == .put && client.requests[2].path == "/api/tournaments/t")
        #expect(client.requests[2].body as? UpdateTournamentPayload == UpdateTournamentPayload(draft: draft))
    }

    @Test func entriesUseTheirRoutesAndBodies() async throws {
        client.responses = [entry, entry, OptionalBody(value: entry), OptionalBody<TournamentEntry>(value: nil), NoContent()]

        _ = try await repository.join(id: "t", teamName: "Görli Giants")
        _ = try await repository.joinTeam(id: "t", entryID: "e1")
        let left = try await repository.leave(id: "t", entryID: "e1", userID: "u-1")
        let emptied = try await repository.leave(id: "t", entryID: "e1", userID: "u-2")
        try await repository.removeEntry(id: "t", entryID: "e1")

        #expect(client.requests[0].method == .post && client.requests[0].path == "/api/tournaments/t/entries")
        #expect(client.requests[0].body as? CreateEntryPayload == CreateEntryPayload(name: "Görli Giants"))
        #expect(client.requests[1].method == .post && client.requests[1].path == "/api/tournaments/t/entries/e1/members")
        #expect(client.requests[2].method == .delete && client.requests[2].path == "/api/tournaments/t/entries/e1/members/u-1")
        #expect(left == entry && emptied == nil)
        #expect(client.requests[4].method == .delete && client.requests[4].path == "/api/tournaments/t/entries/e1")
    }

    @Test func matchesAndLifecycleUseTheirRoutesAndBodies() async throws {
        let match = TournamentMatch(id: "r01p001", tournamentId: "t", round: 1, position: 1)
        client.responses = [detail, detail, detail, detail, detail, match, detail]

        _ = try await repository.start(id: "t")
        _ = try await repository.report(id: "t", matchID: "r01p001", scoreA: 3, scoreB: 1)
        _ = try await repository.confirm(id: "t", matchID: "r01p001")
        _ = try await repository.dispute(id: "t", matchID: "r01p001")
        _ = try await repository.walkover(id: "t", matchID: "r01p001", winnerEntryID: "e1")
        _ = try await repository.schedule(id: "t", matchID: "r01p001", MatchSchedule())
        _ = try await repository.cancel(id: "t")

        let paths = client.requests.map { "\($0.method.rawValue) \($0.path)" }
        #expect(paths == ["POST /api/tournaments/t/start", "PUT /api/tournaments/t/matches/r01p001/result",
                          "POST /api/tournaments/t/matches/r01p001/confirm", "POST /api/tournaments/t/matches/r01p001/dispute",
                          "POST /api/tournaments/t/matches/r01p001/walkover", "PUT /api/tournaments/t/matches/r01p001/schedule",
                          "POST /api/tournaments/t/cancel"])
        #expect(client.requests[1].body as? MatchResultPayload == MatchResultPayload(scoreA: 3, scoreB: 1))
        #expect(client.requests[4].body as? WalkoverPayload == WalkoverPayload(winnerEntryId: "e1"))
    }

    @Test(arguments: codeCases)
    func backendCodesBecomeTheirErrors(testCase: (code: String, expected: AppError)) async {
        client.error = APIError.http(status: 409, body: APIErrorBody(code: testCase.code, message: "m"))
        await #expect(throws: testCase.expected) { try await repository.join(id: "t", teamName: nil) }
    }

    @Test func fallbacksFollowTheRequest() async {
        client.error = APIError.http(status: 500, body: nil)
        await #expect(throws: AppError.tournamentsUnavailable) { try await repository.tournaments(in: .mine, near: nil) }
        await #expect(throws: AppError.tournamentsUnavailable) { try await repository.tournament(id: "t") }
        await #expect(throws: AppError.tournamentCreationFailed) { try await repository.create(.fixture()) }
        await #expect(throws: AppError.tournamentUpdateFailed) { try await repository.update(id: "t", .fixture()) }
        await #expect(throws: AppError.tournamentActionFailed) { try await repository.start(id: "t") }
        client.error = URLError(.notConnectedToInternet)
        await #expect(throws: AppError.network) { try await repository.cancel(id: "t") }
    }

    /// A draft without a spot never reaches the wire.
    @Test func aDraftWithoutACoordinateIsRefusedOnDevice() async {
        await #expect(throws: AppError.tournamentCreationFailed) { try await repository.create(.fixture(coordinate: nil)) }
        #expect(client.requests.isEmpty)
    }

    /// The real client answers a `204` as the empty body the route promised, and refuses it for a type that needs JSON.
    @Test func theClientDecodesAnEmptyBodyForTheTypesThatAllowOne() async throws {
        let backend = StubBackend(status: 204)
        let logger = SpyLogger()
        let client = URLSessionAPIClient(session: backend.makeSession(),
                                         baseURL: backend.baseURL,
                                         identity: FakeIdentityProvider(),
                                         logger: logger)
        let repository = RemoteTournamentRepository(client: client)

        try await repository.removeEntry(id: "t", entryID: "e1")
        #expect(try await repository.leave(id: "t", entryID: "e1", userID: "u") == nil)
        await #expect(throws: AppError.tournamentsUnavailable) { try await repository.tournament(id: "t") }
    }
}
