import Foundation

/// People boundary: other users as the caller may see them, and the direct conversation with one of them. Failures
/// arrive as `AppError`, ready for the popup.
protocol UserRepository {
    /// Throws `AppError.userNotFound` for an unknown or deleted account.
    func profile(userID: String) async throws -> UserProfile
    /// The direct conversation with `userID`: a two-member private group, created on the first call and answered as it
    /// is on every later one (the backend derives one id per pair), so a repeat is safe.
    func startConversation(with userID: String) async throws -> SportGroup
}
