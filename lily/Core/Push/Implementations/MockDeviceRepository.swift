import Foundation

/// Keeps registrations in memory, refusing guests like the backend does.
final class MockDeviceRepository: DeviceRepository {
    private(set) var registrations: [DeviceRegistrationPayload] = []
    private let identity: any IdentityProvider
    private let logger: any Logging
    private let now: () -> Date

    init(identity: any IdentityProvider, logger: any Logging, now: @escaping () -> Date = { .now }) {
        self.identity = identity
        self.logger = logger
        self.now = now
    }

    func register(_ payload: DeviceRegistrationPayload) async throws -> DeviceRegistration {
        guard identity.currentUserID != nil else { throw AppError.sessionExpired }
        registrations.append(payload)
        logger.info(.push, "Mock device registered (\(payload.environment.rawValue))")
        return DeviceRegistration(token: payload.token.lowercased(), environment: payload.environment, registeredAt: now())
    }

    func unregister(token: String) async throws -> DeviceRemoval {
        guard identity.currentUserID != nil else { throw AppError.sessionExpired }
        let before = registrations.count
        registrations.removeAll { $0.token.lowercased() == token.lowercased() }
        logger.info(.push, "Mock device unregistered")
        return DeviceRemoval(token: token.lowercased(), removed: registrations.count < before)
    }
}
