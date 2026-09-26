import Foundation
import Testing
@testable import lily

@MainActor
struct URLSessionAPIClientTests {
    private let logger = SpyLogger()
    private static let localUserHeader = AppConfig.API.Headers.localUserID
    private static let appVersion = AppVersion(marketing: "1.0", build: "42")

    private func makeClient(_ backend: StubBackend,
                            identity: FakeIdentityProvider? = nil,
                            tokenProvider: FakeAuthTokenProvider? = nil,
                            sendsLocalUserHeader: Bool = true) -> URLSessionAPIClient {
        URLSessionAPIClient(session: backend.makeSession(),
                            baseURL: backend.baseURL,
                            identity: identity ?? FakeIdentityProvider(),
                            tokenProvider: tokenProvider,
                            sendsLocalUserHeader: sendsLocalUserHeader,
                            appVersion: Self.appVersion,
                            logger: logger)
    }

    @Test func decodesASuccessfulResponseAndBuildsTheURL() async throws {
        let backend = StubBackend(json: ContractSamples.eventList)
        let query = [URLQueryItem(name: AppConfig.API.Query.scope, value: "upcoming")]

        let events = try await makeClient(backend).send(APIRequest<[SportEvent]>.get(AppConfig.API.Paths.events, query: query))

        #expect(events.map(\.id) == ["evt_01J"])
        let request = try #require(backend.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == backend.baseURL.absoluteString + "/api/events?scope=upcoming")
        #expect(request.value(forHTTPHeaderField: AppConfig.API.Headers.accept) == AppConfig.API.Headers.json)
        #expect(request.httpBody == nil)
    }

    @Test func encodesTheBodyAsJSON() async throws {
        let backend = StubBackend(json: ContractSamples.profile())

        let update = APIRequest<Profile>.put(AppConfig.API.Paths.profile, body: ProfileUpdateRequest(displayName: "Apple Tester"))

        _ = try await makeClient(backend).send(update)

        let request = try #require(backend.requests.first)
        #expect(request.httpMethod == "PUT")
        #expect(request.value(forHTTPHeaderField: AppConfig.API.Headers.contentType) == AppConfig.API.Headers.json)
        let body = try #require(request.httpBody.flatMap { String(bytes: $0, encoding: .utf8) })
        #expect(body == #"{"displayName":"Apple Tester"}"#)
    }

    @Test func postsTheInteractionBatchAndDecodesTheReceipt() async throws {
        let backend = StubBackend(status: 202, json: #"{"accepted":1}"#)
        let interaction = Interaction.presentationChanged(.map, at: Date(timeIntervalSince1970: 1_800_000_000))
        let request = APIRequest<InteractionReceipt>.post(AppConfig.API.Paths.interactions,
                                                          body: InteractionBatch(interactions: [interaction]))

        let receipt = try await makeClient(backend).send(request)

        #expect(receipt == InteractionReceipt(accepted: 1))
        let sent = try #require(backend.requests.first)
        #expect(sent.httpMethod == "POST")
        #expect(sent.url?.path() == "/api/interactions")
        let data = try #require(sent.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let first = try #require((body["interactions"] as? [[String: Any]])?.first)
        let expected: [String: String] = ["kind": "presentation_changed", "occurredAt": "2027-01-15T08:00:00Z",
                                          "presentation": "map"]
        #expect(first as NSDictionary == expected as NSDictionary)
    }

    @Test func errorBodyBecomesAnAPIErrorAndIsLogged() async {
        let backend = StubBackend(status: 409, json: #"{"code":"EVENT_FULL","message":"No spots left"}"#)
        let path = AppConfig.API.Paths.participants(eventId: "evt_01J")

        await #expect(throws: APIError.http(status: 409, body: APIErrorBody(code: "EVENT_FULL", message: "No spots left"))) {
            try await makeClient(backend).send(APIRequest<SportEvent>.post(path))
        }
        #expect(logger.messages(in: .network).contains { $0.contains("POST \(path)") && $0.contains("409") })
        #expect(!logger.entries.contains { $0.message.contains("No spots left") }, "the body itself must not be logged")
    }

    /// The backend's 429 names how long to wait; the header travels with the error so the composer can honour it.
    @Test func retryAfterHeaderTravelsWithTheError() async {
        let body = #"{"code":"RATE_LIMITED","message":"Slow down"}"#
        let backend = StubBackend(status: 429, json: body, headers: [AppConfig.API.Headers.retryAfter: "7"])

        let expected = APIError.http(status: 429, body: APIErrorBody(code: "RATE_LIMITED", message: "Slow down"), retryAfter: 7)
        await #expect(throws: expected) {
            try await makeClient(backend).send(APIRequest<Profile>.get(AppConfig.API.Paths.profile))
        }

        let dated = StubBackend(status: 429, headers: [AppConfig.API.Headers.retryAfter: "Wed, 21 Oct 2026 07:28:00 GMT"])
        await #expect(throws: APIError.http(status: 429, body: nil, retryAfter: nil)) {
            try await makeClient(dated).send(APIRequest<Profile>.get(AppConfig.API.Paths.profile))
        }
    }

    @Test func emptyErrorBodyKeepsTheStatus() async {
        let backend = StubBackend(status: 401)

        await #expect(throws: APIError.http(status: 401, body: nil)) {
            try await makeClient(backend).send(APIRequest<[SportEvent]>.get(AppConfig.API.Paths.events))
        }
    }

    @Test func undecodableBodyIsADecodingFailure() async {
        let backend = StubBackend(json: #"{"unexpected":true}"#)

        await #expect(throws: APIError.decodingFailed) {
            try await makeClient(backend).send(APIRequest<Profile>.get(AppConfig.API.Paths.profile))
        }
    }

    @Test func transportFailureIsRethrownAndLogged() async {
        let backend = StubBackend { _ in .failure(URLError(.notConnectedToInternet)) }

        await #expect(throws: URLError.self) {
            try await makeClient(backend).send(APIRequest<[SportEvent]>.get(AppConfig.API.Paths.events))
        }
        #expect(logger.messages(in: .network).contains { $0.contains("GET /api/events") && $0.contains("failed") })
    }

    /// Reads and writes alike, guest or signed in: the backend can tell every request's app version apart.
    @Test func appVersionHeaderIsSentOnEveryRequest() async throws {
        let backend = StubBackend(json: ContractSamples.profile())
        let client = makeClient(backend, tokenProvider: FakeAuthTokenProvider(token: nil))

        _ = try await client.send(APIRequest<Profile>.get(AppConfig.API.Paths.profile))
        _ = try await client.send(APIRequest<Profile>.put(AppConfig.API.Paths.profile,
                                                          body: ProfileUpdateRequest(displayName: "Apple Tester")))

        let sent = backend.requests.map { $0.value(forHTTPHeaderField: AppConfig.API.Headers.appVersion) }
        #expect(sent == ["1.0 (42)", "1.0 (42)"])
    }

    private struct HeaderCase {
        let configured: Bool
        let userID: String?
        let header: String?
    }

    @Test func localUserHeaderIsSentOnlyWhenConfiguredAndSignedIn() async throws {
        let cases = [
            HeaderCase(configured: true, userID: "u-1", header: "u-1"),
            HeaderCase(configured: true, userID: nil, header: nil),
            HeaderCase(configured: false, userID: "u-1", header: nil),
        ]
        for testCase in cases {
            let backend = StubBackend(json: ContractSamples.profile())
            let client = makeClient(backend,
                                    identity: FakeIdentityProvider(currentUserID: testCase.userID),
                                    sendsLocalUserHeader: testCase.configured)

            _ = try await client.send(APIRequest<Profile>.get(AppConfig.API.Paths.profile))

            let request = try #require(backend.requests.first)
            #expect(request.value(forHTTPHeaderField: Self.localUserHeader) == testCase.header,
                    "configured: \(testCase.configured), user: \(testCase.userID ?? "none")")
        }
    }

    @Test func bearerTokenIsSentWhenTheProviderHasOne() async throws {
        let backend = StubBackend(json: ContractSamples.profile())
        let tokens = FakeAuthTokenProvider(token: "eyJ.access")
        let client = makeClient(backend, identity: FakeIdentityProvider(currentUserID: "u-1"), tokenProvider: tokens)

        _ = try await client.send(APIRequest<Profile>.get(AppConfig.API.Paths.profile))

        let request = try #require(backend.requests.first)
        #expect(request.value(forHTTPHeaderField: AppConfig.API.Headers.authorization) == "Bearer eyJ.access")
        #expect(tokens.requestCount == 1)
        #expect(!logger.entries.contains { $0.message.contains("eyJ.access") }, "the token must never be logged")
    }

    @Test func noAuthorizationHeaderWithoutAToken() async throws {
        for tokens in [nil, FakeAuthTokenProvider(token: nil)] {
            let backend = StubBackend(json: ContractSamples.profile())
            let client = makeClient(backend, identity: FakeIdentityProvider(currentUserID: "u-1"), tokenProvider: tokens)

            _ = try await client.send(APIRequest<Profile>.get(AppConfig.API.Paths.profile))

            let request = try #require(backend.requests.first)
            #expect(request.value(forHTTPHeaderField: AppConfig.API.Headers.authorization) == nil)
        }
    }

    /// The Bearer follows the app's session, not Amplify's keychain: a token left behind by a rolled-back sign-in must
    /// not personalise what the app shows as a guest, so the provider is not even asked while there is no user.
    @Test func noAuthorizationHeaderWhileTheAppHasNoUser() async throws {
        let backend = StubBackend(json: ContractSamples.profile())
        let tokens = FakeAuthTokenProvider(token: "eyJ.access")
        let client = makeClient(backend, identity: FakeIdentityProvider(currentUserID: nil), tokenProvider: tokens)

        _ = try await client.send(APIRequest<Profile>.get(AppConfig.API.Paths.profile))

        let request = try #require(backend.requests.first)
        #expect(request.value(forHTTPHeaderField: AppConfig.API.Headers.authorization) == nil)
        #expect(tokens.requestCount == 0)
    }

    /// The token is asked for on every request, so one refreshed by Amplify or dropped by a sign-out is picked up.
    @Test func tokenIsReadPerRequest() async throws {
        let backend = StubBackend(json: ContractSamples.profile())
        let tokens = FakeAuthTokenProvider(token: "first")
        let client = makeClient(backend, identity: FakeIdentityProvider(currentUserID: "u-1"), tokenProvider: tokens)

        _ = try await client.send(APIRequest<Profile>.get(AppConfig.API.Paths.profile))
        tokens.token = nil
        _ = try await client.send(APIRequest<Profile>.get(AppConfig.API.Paths.profile))

        let sent = backend.requests.map { $0.value(forHTTPHeaderField: AppConfig.API.Headers.authorization) }
        #expect(sent == ["Bearer first", nil])
    }

    @Test func identityIsReadPerRequest() async throws {
        let backend = StubBackend(json: ContractSamples.profile())
        let identity = FakeIdentityProvider()
        let client = makeClient(backend, identity: identity)

        _ = try await client.send(APIRequest<Profile>.get(AppConfig.API.Paths.profile))
        identity.currentUserID = "u-2"
        _ = try await client.send(APIRequest<Profile>.get(AppConfig.API.Paths.profile))

        #expect(backend.requests.map { $0.value(forHTTPHeaderField: Self.localUserHeader) } == [nil, "u-2"])
    }

    @Test func instantsParseWithAndWithoutFractionalSeconds() async throws {
        let tenOClock = Date(timeIntervalSince1970: 1_789_120_800)
        for (text, fraction) in [("2026-09-11T10:00:00Z", 0.0), ("2026-09-11T10:00:00.250Z", 0.25)] {
            let backend = StubBackend(json: ContractSamples.profile(createdAt: text))

            let profile = try await makeClient(backend).send(APIRequest<Profile>.get(AppConfig.API.Paths.profile))

            #expect(abs(profile.createdAt.timeIntervalSince(tenOClock) - fraction) < 0.001, "\(text)")
        }
    }

    @Test func malformedInstantFailsDecoding() async {
        let backend = StubBackend(json: ContractSamples.profile(createdAt: "yesterday"))

        await #expect(throws: APIError.decodingFailed) {
            try await makeClient(backend).send(APIRequest<Profile>.get(AppConfig.API.Paths.profile))
        }
    }
}
