import Foundation

/// The caller's profile on the backend: the name other players see and the bio under it. Identity stays with Cognito;
/// the backend creates the profile with its default name on first contact, so a read never finds nothing.
protocol ProfileRepository {
    /// `GET /api/profile`.
    func profile() async throws -> Profile
    /// `PUT /api/profile`; the answer carries the name as the backend stored it (trimmed, cut to its cap).
    func updateDisplayName(_ name: String) async throws -> Profile
    /// `PUT /api/profile` with the bio alone; a blank clears it. The answer carries it as stored (stripped, cut to its cap).
    func updateBio(_ bio: String) async throws -> Profile
}
