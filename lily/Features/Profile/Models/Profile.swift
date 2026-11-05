import Foundation

/// The backend's `Profile`.
nonisolated struct Profile: Codable, Hashable, Sendable {
    let userId: String
    let displayName: String
    let createdAt: Date
    /// What the user wrote about themselves; absent until they did.
    let bio: String?

    init(userId: String, displayName: String, createdAt: Date, bio: String? = nil) {
        self.userId = userId
        self.displayName = displayName
        self.createdAt = createdAt
        self.bio = bio
    }
}

/// Body of `PUT /api/profile`: the name, or the bio, each written on its own; the absent field is left out of the JSON,
/// never sent as `null`, so the backend changes one thing.
nonisolated struct ProfileUpdateRequest: Codable, Hashable, Sendable {
    let displayName: String?
    let bio: String?

    init(displayName: String) {
        self.displayName = displayName
        bio = nil
    }

    /// A blank clears the bio.
    init(bio: String) {
        displayName = nil
        self.bio = bio
    }
}
