import Foundation
import Testing
@testable import lily

@MainActor
struct DeviceRepositoryTests {
    private let client = FakeAPIClient()
    private let token = String(repeating: "ab", count: 32)

    private var remote: RemoteDeviceRepository { RemoteDeviceRepository(client: client) }

    @Test func registerPutsThePayloadToTheDevicesRoute() async throws {
        let payload = DeviceRegistrationPayload(token: token,
                                                platform: "ios",
                                                environment: .sandbox,
                                                appVersion: "1.0 (42)",
                                                locale: "en")
        let stored = DeviceRegistration(token: token, environment: .sandbox, registeredAt: .now)
        client.responses = [stored]

        #expect(try await remote.register(payload) == stored)
        let request = try #require(client.requests.first)
        #expect(request.method == .put && request.path == "/api/me/devices")
        #expect(request.body as? DeviceRegistrationPayload == payload)
    }

    @Test func unregisterDeletesTheTokensRoute() async throws {
        client.responses = [DeviceRemoval(token: token, removed: true)]

        #expect(try await remote.unregister(token: token).removed)
        let request = try #require(client.requests.first)
        #expect(request.method == .delete && request.path == "/api/me/devices/\(token)" && request.body == nil)
    }

    @Test func failuresKeepTheSharedMappingAndFallBackToUnknown() async {
        client.error = APIError.http(status: 401, body: nil)
        await #expect(throws: AppError.sessionExpired) { try await remote.unregister(token: token) }
        client.error = APIError.http(status: 400, body: APIErrorBody(code: "VALIDATION_FAILED", message: "m"))
        let payload = DeviceRegistrationPayload(token: "x", platform: "ios", environment: .sandbox, appVersion: "1", locale: "en")
        await #expect(throws: AppError.unknown) { try await remote.register(payload) }
        client.error = URLError(.notConnectedToInternet)
        await #expect(throws: AppError.network) { try await remote.unregister(token: token) }
    }

    @Test func theMockRefusesGuestsAndRemembersRegistrations() async throws {
        let identity = FakeIdentityProvider()
        let mock = MockDeviceRepository(identity: identity, logger: SpyLogger())
        let payload = DeviceRegistrationPayload(token: token.uppercased(),
                                                platform: "ios",
                                                environment: .sandbox,
                                                appVersion: "1",
                                                locale: "en")
        await #expect(throws: AppError.sessionExpired) { try await mock.register(payload) }

        identity.currentUserID = TestFixtures.user.id
        let registration = try await mock.register(payload)

        #expect(registration.token == token && mock.registrations == [payload])
        #expect(try await mock.unregister(token: token).removed)
        #expect(try await mock.unregister(token: token).removed == false)
    }
}
