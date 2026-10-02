import Foundation

/// Grants without a prompt and answers a fixed token, so `-mock-events` runs, previews and UI tests never meet the
/// system alert or APNs.
final class MockPushRegistrar: PushRegistrar {
    private(set) var status: PushAuthorization = .notDetermined
    private let logger: any Logging

    init(logger: any Logging) {
        self.logger = logger
    }

    func authorization() async -> PushAuthorization {
        status
    }

    func requestAuthorization() async -> Bool {
        status = .authorized
        logger.info(.push, "Mock notification permission granted")
        return true
    }

    func deviceToken() async throws -> String {
        AppConfig.Push.mockToken
    }
}
