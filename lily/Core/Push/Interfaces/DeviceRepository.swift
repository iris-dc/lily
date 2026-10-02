import Foundation

/// The backend's device registry: where this device's APNs token goes so reminders can reach it.
protocol DeviceRepository {
    func register(_ payload: DeviceRegistrationPayload) async throws -> DeviceRegistration
    func unregister(token: String) async throws -> DeviceRemoval
}
