import Foundation
import Testing
@testable import lily

/// The shared failure mapping of `send(_:failingWith:)`, proved once here; the remote repository suites rely on it and
/// test only what their routes add (one known code, their own fallback).
@MainActor
struct SendFailingWithTests {
    private let client = FakeAPIClient()
    private let request = APIRequest<Profile>.get("/api/profile")
    private let profile = Profile(userId: "u-1", displayName: "Apple Tester", createdAt: .now)

    private func send() async throws -> Profile {
        try await client.send(request, failingWith: .eventsUnavailable)
    }

    @Test func anAnswerPassesThroughUnchanged() async throws {
        client.responses = [profile]

        let answer = try await send()

        #expect(answer == profile)
        #expect(client.requests.count == 1)
        #expect(client.requests.first?.method == .get && client.requests.first?.path == "/api/profile")
    }

    @Test func aKnownBackendCodeBecomesItsOwnCase() async {
        client.error = APIError.http(status: 409, body: APIErrorBody(code: "EVENT_FULL", message: "m"))

        await #expect(throws: AppError.eventFull) { try await send() }
    }

    /// A code the app does not know and a status without a body say nothing the caller can act on, so the route's
    /// fallback speaks.
    @Test func anUnknownCodeAndACodelessStatusBecomeTheFallback() async {
        let failures: [APIError] = [
            .http(status: 409, body: APIErrorBody(code: "SOMETHING_NEW", message: "m")),
            .http(status: 500, body: nil), .decodingFailed, .notHTTPResponse,
        ]
        for failure in failures {
            client.error = failure
            await #expect(throws: AppError.eventsUnavailable, "\(failure)") { try await send() }
        }
    }

    /// A 401 is about the token, not about what was asked, so a body naming another refusal does not change it.
    @Test func aRefusedTokenIsSessionExpiredWhateverTheBodySays() async {
        client.error = APIError.http(status: 401, body: nil)
        await #expect(throws: AppError.sessionExpired) { try await send() }

        client.error = APIError.http(status: 401, body: APIErrorBody(code: "EVENT_FULL", message: "m"))
        await #expect(throws: AppError.sessionExpired) { try await send() }
    }

    /// A 429 is about the caller's pace: the `Retry-After` seconds ride along, and the body may be missing.
    @Test func aThrottledCallIsRateLimitedWithItsRetryAfter() async {
        client.error = APIError.http(status: 429, body: nil, retryAfter: 7)
        await #expect(throws: AppError.rateLimited(retryAfter: 7)) { try await send() }

        client.error = APIError.http(status: 429, body: APIErrorBody(code: "RATE_LIMITED", message: "m"))
        await #expect(throws: AppError.rateLimited(retryAfter: nil)) { try await send() }
    }

    @Test func aTransportFailureIsNetwork() async {
        client.error = URLError(.notConnectedToInternet)
        await #expect(throws: AppError.network) { try await send() }

        client.error = URLError(.timedOut)
        await #expect(throws: AppError.network) { try await send() }
    }

    /// Screens stay quiet on cancellation, so neither form of it may be turned into a failure.
    @Test func cancellationPassesThroughUntouched() async {
        client.error = URLError(.cancelled)
        await #expect(throws: URLError(.cancelled)) { try await send() }

        client.error = CancellationError()
        await #expect(throws: CancellationError.self) { try await send() }
    }
}
