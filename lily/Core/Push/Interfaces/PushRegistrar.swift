import Foundation

/// The system's notification permission and remote-notification registration, behind a seam so the coordinator is
/// testable and a mock run (`-mock-events`) never meets the permission alert.
protocol PushRegistrar {
    func authorization() async -> PushAuthorization
    /// Shows the system prompt; `true` when granted.
    func requestAuthorization() async -> Bool
    /// Registers with the system and answers the APNs device token as hex; throws when the system refused or stayed silent.
    func deviceToken() async throws -> String
}
