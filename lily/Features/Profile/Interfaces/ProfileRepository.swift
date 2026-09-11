import Foundation

/// The user's profile on the backend. Identity stays with Cognito; this only carries what the backend shows to others.
protocol ProfileRepository {
    /// Tells the backend the name to show on events the user hosts.
    func syncDisplayName(_ name: String) async throws
}
