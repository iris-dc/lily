import Foundation
import Testing
@testable import lily

@MainActor
struct RemoteEventRepositoryTests {
    private static let codeCases: [(code: String, expected: AppError)] = [
        ("EVENT_FULL", .eventFull),
        ("ALREADY_JOINED", .alreadyJoined),
        ("NOT_A_PARTICIPANT", .notAParticipant),
        ("HOST_CANNOT_LEAVE", .hostCannotLeave),
        ("EVENT_NOT_FOUND", .eventNotFound),
        ("VALIDATION_FAILED", .eventsUnavailable),
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

    @Test func otherHTTPFailuresBecomeEventsUnavailable() async {
        for error in [APIError.http(status: 500, body: nil), .http(status: 401, body: nil), .decodingFailed, .notHTTPResponse] {
            client.error = error
            await #expect(throws: AppError.eventsUnavailable) { try await repository.events(in: .upcoming) }
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

    @Test func failuresPropagate() async {
        client.error = APIError.http(status: 400, body: APIErrorBody(code: "VALIDATION_FAILED", message: "empty"))

        await #expect(throws: APIError.self) { try await RemoteProfileRepository(client: client).syncDisplayName("") }
    }
}
