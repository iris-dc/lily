import Foundation
import Testing
@testable import lily

@MainActor
struct URLSessionAPIClientQueryAndLogTests {
    private let logger = SpyLogger()

    /// `nonisolated`: `@Test(arguments:)` reads it off the main actor. A 5xx with a known code, a 4xx with a code the
    /// app does not know, and a 5xx without a body.
    nonisolated private static let faults: [(status: Int, json: String)] = [
        (500, #"{"code":"EVENT_FULL","message":"x"}"#),
        (400, #"{"code":"VALIDATION_FAILED","message":"x"}"#),
        (502, ""),
    ]

    private func makeClient(_ backend: StubBackend) -> URLSessionAPIClient {
        URLSessionAPIClient(session: backend.makeSession(),
                            baseURL: backend.baseURL,
                            identity: FakeIdentityProvider(),
                            appVersion: AppVersion(marketing: "1.0", build: "42"),
                            logger: logger)
    }

    @Test func aPlusInAQueryValueIsEncoded() async throws {
        let backend = StubBackend(json: "[]")
        let query = [URLQueryItem(name: "q", value: "a+b c")]

        _ = try await makeClient(backend).send(APIRequest<[SportEvent]>.get(AppConfig.API.Paths.events, query: query))

        let url = try #require(backend.requests.first?.url)
        #expect(url.query(percentEncoded: true) == "q=a%2Bb%20c")
        #expect(url.path() == AppConfig.API.Paths.events)
    }

    @Test func theDeviceTokenNeverReachesTheLog() async throws {
        let backend = StubBackend(status: 500)
        let token = String(repeating: "ab", count: 32)
        let repository = RemoteDeviceRepository(client: makeClient(backend))

        await #expect(throws: AppError.self) { try await repository.unregister(token: token) }

        #expect(backend.requests.first?.url?.path() == AppConfig.API.Paths.device(token: token))
        #expect(!logger.entries.contains { $0.message.contains(token) })
        let redacted = "DELETE \(AppConfig.API.Paths.device(token: AppConfig.Push.redactedToken))"
        #expect(logger.messages(in: .network, at: .error).contains { $0.contains(redacted) && $0.contains("500") })
    }

    @Test func aBackendRefusalLogsAtWarning() async throws {
        let backend = StubBackend(status: 409, json: #"{"code":"EVENT_FULL","message":"No spots left"}"#)
        let request = APIRequest<SportEvent>.post(AppConfig.API.Paths.participants(eventId: "evt_01J"))

        await #expect(throws: APIError.self) { try await makeClient(backend).send(request) }

        let warnings = logger.messages(in: .network, at: .warning)
        #expect(warnings.count == 1)
        #expect(warnings.first?.contains("409") == true && warnings.first?.contains("EVENT_FULL") == true)
        #expect(logger.messages(in: .network, at: .error).isEmpty)
    }

    @Test func aRejectedTokenLogsAtWarningEvenWithoutABody() async throws {
        let backend = StubBackend(status: 401)
        let request = APIRequest<[SportEvent]>.get(AppConfig.API.Paths.events)

        await #expect(throws: APIError.self) { try await makeClient(backend).send(request) }

        #expect(logger.messages(in: .network, at: .warning).contains { $0.contains("401") })
        #expect(logger.messages(in: .network, at: .error).isEmpty)
    }

    @Test(arguments: faults)
    func aFaultOrAnUnknownCodeLogsAtError(status: Int, json: String) async throws {
        let backend = StubBackend(status: status, json: json)
        let request = APIRequest<[SportEvent]>.get(AppConfig.API.Paths.events)

        await #expect(throws: APIError.self) { try await makeClient(backend).send(request) }

        let errors = logger.messages(in: .network, at: .error)
        #expect(errors.count == 1)
        #expect(errors.first?.contains(String(status)) == true)
        #expect(logger.messages(in: .network, at: .warning).isEmpty)
    }
}
