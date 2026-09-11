import Foundation

/// The backend's `Profile`.
nonisolated struct Profile: Codable, Hashable, Sendable {
    let userId: String
    let displayName: String
    let createdAt: Date
}

/// Body of `PUT /api/profile`.
nonisolated struct ProfileUpdateRequest: Codable, Hashable, Sendable {
    let displayName: String
}
