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
        .http(status: 500, body: nil), .http(status: 401, body: nil), .decodingFailed, .notHTTPResponse,
    ]

    private let client = FakeAPIClient()
    private let event = MockEventFixtures.make(now: .now, count: 1)[0]

    private var repository: RemoteEventRepository { RemoteEventRepository(client: client) }

    @Test func scopesBecomeTheScopeQueryParameter() async throws {
        client.responses = [[SportEvent](), [SportEvent]()]

        _ = try await repository.events(in: .upcoming)
        _ = try await repository.events(in: .joined)

        #expect(client.requests.map(\.method) == [.get, .get])
        #expect(client.requests.map(\.path) == ["/api/events", "/api/events"])
        let expectedQueries = [
            [URLQueryItem(name: "scope", value: "upcoming")],
            [URLQueryItem(name: "scope", value: "joined")],
        ]
        #expect(client.requests.map(\.queryItems) == expectedQueries)
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

    @Test(arguments: codeCases)
    func backendCodesMapToAppErrors(code: String, expected: AppError) async {
        client.error = APIError.http(status: 409, body: APIErrorBody(code: code, message: "m"))

        await #expect(throws: expected) { try await repository.join(eventId: "evt_01J") }
    }

    @Test func otherFailuresOnReadsBecomeEventsUnavailable() async {
        for error in Self.otherFailures {
            client.error = error
            await #expect(throws: AppError.eventsUnavailable) { try await repository.events(in: .upcoming) }
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

    @Test func transportFailuresBecomeNetwork() async {
        client.error = URLError(.notConnectedToInternet)

        await #expect(throws: AppError.network) { try await repository.events(in: .upcoming) }
    }

    /// The list view model keeps quiet on cancellation, so the repository must not turn it into a failure.
    @Test func cancellationPassesThroughUntouched() async {
        client.error = URLError(.cancelled)
        await #expect(throws: URLError(.cancelled)) { try await repository.events(in: .upcoming) }

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
