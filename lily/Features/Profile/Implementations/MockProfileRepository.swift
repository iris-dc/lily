import Foundation

/// Accepts every name, so previews, UI tests and `-mock-events` runs never need a backend.
final class MockProfileRepository: ProfileRepository {
    private let logger: any Logging

    init(logger: any Logging) {
        self.logger = logger
    }

    func syncDisplayName(_ name: String) async throws {
        logger.debug(.auth, "Mock profile sync accepted a display name")
    }
}
