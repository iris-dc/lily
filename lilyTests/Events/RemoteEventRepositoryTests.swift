import Foundation
import Testing
@testable import lily

@MainActor
struct RemoteEventRepositoryTests {
    /// `nonisolated`: `@Test(arguments:)` reads it off the main actor.
    nonisolated private static let codeCases: [(code: String, expected: AppError)] = [
        ("EVENT_FULL", .eventFull),
        ("ALREADY_JOINED", .alreadyJoined),
        ("NOT_A_PARTICIPANT", .notAParticipant),
        ("HOST_CANNOT_LEAVE", .hostCannotLeave),
        ("TRY_AGAIN", .tryAgain),
        ("EVENT_NOT_FOUND", .eventNotFound),
        ("VALIDATION_FAILED", .participationFailed),
    ]
    /// Failures without a backend code of their own; what they become depends on what was being asked.
    private static let otherFailures: [APIError] = [
        .http(status: 500, body: nil), .http(status: 403, body: nil), .decodingFailed, .notHTTPResponse,
    ]

    private let client = FakeAPIClient()
    private let event = MockEventFixtures.make(now: .now, count: 1)[0]

    private var repository: RemoteEventRepository { RemoteEventRepository(client: client) }

    @Test func scopesBecomeTheScopeQueryParameter() async throws {
        client.responses = [[SportEvent](), [SportEvent]()]

        _ = try await repository.events(in: .upcoming, near: nil)
        _ = try await repository.events(in: .joined, near: nil)

        #expect(client.requests.map(\.method) == [.get, .get])
        #expect(client.requests.map(\.path) == ["/api/events", "/api/events"])
        let expectedQueries = [
            [URLQueryItem(name: "scope", value: "upcoming")],
            [URLQueryItem(name: "scope", value: "joined")],
        ]
        #expect(client.requests.map(\.queryItems) == expectedQueries)
    }

    /// Pins the wire rule: two decimals (about a kilometre), halves away from zero, fixed width, a `.` whatever the locale.
    @Test func upcomingWithAPositionSendsRoundedLatAndLon() async throws {
        client.responses = [[SportEvent]()]

        _ = try await repository.events(in: .upcoming, near: Coordinate(latitude: 52.5449, longitude: -0.125))

        let request = try #require(client.requests.first)
        #expect(request.queryItems == [URLQueryItem(name: "scope", value: "upcoming"),
                                       URLQueryItem(name: "lat", value: "52.54"),
                                       URLQueryItem(name: "lon", value: "-0.13")])
    }

    @Test func aWholeDegreeKeepsItsDecimals() async throws {
        client.responses = [[SportEvent]()]

        _ = try await repository.events(in: .upcoming, near: Coordinate(latitude: 52, longitude: 13.4))

        #expect(client.requests.first?.queryItems.dropFirst().map(\.value) == ["52.00", "13.40"])
    }

    /// My Events is the caller's own games; their position has no business in that request.
    @Test func joinedNeverSendsAPosition() async throws {
        client.responses = [[SportEvent]()]

        _ = try await repository.events(in: .joined, near: AppConfig.Location.mockCenter)

        #expect(client.requests.first?.queryItems == [URLQueryItem(name: "scope", value: "joined")])
    }

    @Test func eventGetsTheEventResource() async throws {
        client.responses = [event]

        let fetched = try await repository.event(id: "evt_01J")

        #expect(fetched == event)
        let request = try #require(client.requests.first)
        #expect(request.method == .get)
        #expect(request.path == "/api/events/evt_01J")
        #expect(request.queryItems.isEmpty && request.body == nil)
    }

    @Test func joinPostsAndLeaveDeletesTheParticipantsResource() async throws {
        client.responses = [event, event]

        let joined = try await repository.join(eventId: "evt_01J")
        let left = try await repository.leave(eventId: "evt_01J")

        #expect(joined == event)
        #expect(left == event)
        #expect(client.requests.map(\.method) == [.post, .delete])
        #expect(client.requests.map(\.path) == Array(repeating: "/api/events/evt_01J/participants", count: 2))
        #expect(client.requests.allSatisfy { $0.body == nil && $0.queryItems.isEmpty })
    }

    @Test func createPostsThePayloadToEvents() async throws {
        let draft = EventDraft.fixture()
        client.responses = [event]

        let created = try await repository.create(draft)

        #expect(created == event)
        let request = try #require(client.requests.first)
        #expect(request.method == .post)
        #expect(request.path == "/api/events")
        #expect(request.queryItems.isEmpty)
        let payload = try #require(request.body as? CreateEventPayload)
        #expect(payload == CreateEventPayload(draft: draft))
        let encoded = try APIJSONCoding.makeEncoder().encode(payload)
        let json = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(json["clientEventId"] as? String == draft.clientId)
        #expect(TestFixtures.isBackendEventId(draft.clientId))
        #expect(!json.keys.contains("description") && !json.keys.contains("price"))
    }

    /// Validated before the request is built: a draft without a spot never reaches the backend.
    @Test func createWithoutACoordinateFailsBeforeAnyRequest() async {
        await #expect(throws: AppError.eventCreationFailed) { try await repository.create(.fixture(coordinate: nil)) }
        #expect(client.requests.isEmpty)
    }

    /// The form validates against the backend's limits, so `VALIDATION_FAILED` has no copy of its own on a create;
    /// like `EVENT_ID_TAKEN` (another user's id) and a 500 it becomes the generic creation failure.
    @Test func createFailuresWithoutCopyBecomeEventCreationFailed() async {
        let coded = ["VALIDATION_FAILED", "EVENT_ID_TAKEN"].map {
            APIError.http(status: 400, body: APIErrorBody(code: $0, message: "m"))
        }
        for error in coded + Self.otherFailures {
            client.error = error
            await #expect(throws: AppError.eventCreationFailed) { try await repository.create(.fixture()) }
        }
    }

    /// A create that lost a race keeps its own copy: repeating it with the same client id is safe.
    @Test func createTryAgainAndTransportFailuresKeepTheirOwnErrors() async {
        client.error = APIError.http(status: 409, body: APIErrorBody(code: "TRY_AGAIN", message: "m"))
        await #expect(throws: AppError.tryAgain) { try await repository.create(.fixture()) }

        client.error = URLError(.notConnectedToInternet)
        await #expect(throws: AppError.network) { try await repository.create(.fixture()) }

        client.error = URLError(.cancelled)
        await #expect(throws: URLError(.cancelled)) { try await repository.create(.fixture()) }
    }

    @Test(arguments: codeCases)
    func backendCodesMapToAppErrors(code: String, expected: AppError) async {
        client.error = APIError.http(status: 409, body: APIErrorBody(code: code, message: "m"))

        await #expect(throws: expected) { try await repository.join(eventId: "evt_01J") }
    }

    @Test func otherFailuresOnReadsBecomeEventsUnavailable() async {
        for error in Self.otherFailures {
            client.error = error
            await #expect(throws: AppError.eventsUnavailable) { try await repository.events(in: .upcoming, near: nil) }
            await #expect(throws: AppError.eventsUnavailable) { try await repository.event(id: "evt_01J") }
        }
    }

    /// A join that fails for no named reason is about the spot, not the list, and must not say "Events unavailable".
    @Test func otherFailuresOnJoinAndLeaveBecomeParticipationFailed() async {
        for error in Self.otherFailures {
            client.error = error
            await #expect(throws: AppError.participationFailed) { try await repository.join(eventId: "evt_01J") }
            await #expect(throws: AppError.participationFailed) { try await repository.leave(eventId: "evt_01J") }
        }
    }

    /// A 401 is about the token, not about what was asked, so it keeps its own copy on reads, writes and creates alike.
    @Test func unauthorizedBecomesSessionExpiredWhateverWasAsked() async {
        client.error = APIError.http(status: 401, body: nil)

        await #expect(throws: AppError.sessionExpired) { try await repository.events(in: .joined, near: nil) }
        await #expect(throws: AppError.sessionExpired) { try await repository.join(eventId: "evt_01J") }
        await #expect(throws: AppError.sessionExpired) { try await repository.create(.fixture()) }
    }

    @Test func transportFailuresBecomeNetwork() async {
        client.error = URLError(.notConnectedToInternet)

        await #expect(throws: AppError.network) { try await repository.events(in: .upcoming, near: nil) }
    }

    /// The list view model keeps quiet on cancellation, so the repository must not turn it into a failure.
    @Test func cancellationPassesThroughUntouched() async {
        client.error = URLError(.cancelled)
        await #expect(throws: URLError(.cancelled)) { try await repository.events(in: .upcoming, near: nil) }

        client.error = CancellationError()
        await #expect(throws: CancellationError.self) { try await repository.leave(eventId: "evt_01J") }
    }
}

@MainActor
struct RemoteProfileRepositoryTests {
    private let client = FakeAPIClient()

    @Test func syncPutsTheDisplayName() async throws {
        client.responses = [Profile(userId: "u-1", displayName: "Apple Tester", createdAt: .now)]

        try await RemoteProfileRepository(client: client).syncDisplayName("Apple Tester")

        let request = try #require(client.requests.first)
        #expect(request.method == .put)
        #expect(request.path == "/api/profile")
        #expect(request.body as? ProfileUpdateRequest == ProfileUpdateRequest(displayName: "Apple Tester"))
    }

    /// The caller logs what it catches, so it must be a clean `AppError`, never an `APIError` carrying the backend's
    /// message body; cancellation passes through for the caller's `isCancellation` check.
    @Test func failuresBecomeAppErrors() async {
        let repository = RemoteProfileRepository(client: client)

        client.error = APIError.http(status: 400, body: APIErrorBody(code: "VALIDATION_FAILED", message: "empty"))
        await #expect(throws: AppError.unknown) { try await repository.syncDisplayName("") }

        client.error = URLError(.notConnectedToInternet)
        await #expect(throws: AppError.network) { try await repository.syncDisplayName("Apple Tester") }

        client.error = URLError(.cancelled)
        await #expect(throws: URLError(.cancelled)) { try await repository.syncDisplayName("Apple Tester") }
    }
}
