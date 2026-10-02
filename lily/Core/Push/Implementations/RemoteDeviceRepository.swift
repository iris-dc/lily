import Foundation

/// A registration failure is never shown, so the fallback stays `.unknown` and the coordinator logs it.
final class RemoteDeviceRepository: DeviceRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    func register(_ payload: DeviceRegistrationPayload) async throws -> DeviceRegistration {
        let request = APIRequest<DeviceRegistration>.put(AppConfig.API.Paths.devices, body: payload)
        return try await client.send(request, failingWith: .unknown)
    }

    func unregister(token: String) async throws -> DeviceRemoval {
        try await client.send(.delete(AppConfig.API.Paths.device(token: token)), failingWith: .unknown)
    }
}
