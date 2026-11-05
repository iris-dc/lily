import Foundation

/// Mirrors Laurel's profile rules in memory, so previews, UI tests and `-mock-events` runs see what a new account sees:
/// a profile created with the default name on the first read, a rename trimmed and cut to the cap, a blank name falling
/// back to the default, a bio trimmed and cut to its cap and cleared by a blank. No word filter, since no mock has one.
final class MockProfileRepository: ProfileRepository {
    private var profiles: [String: Profile] = [:]
    private let identity: any IdentityProvider
    private let logger: any Logging
    private let now: () -> Date

    init(identity: any IdentityProvider, logger: any Logging, now: @escaping () -> Date = { .now }) {
        self.identity = identity
        self.logger = logger
        self.now = now
    }

    func profile() async throws -> Profile {
        let userID = try caller()
        if let profile = profiles[userID] { return profile }
        let created = Profile(userId: userID, displayName: AppConfig.DisplayName.backendDefault, createdAt: now())
        profiles[userID] = created
        logger.debug(.auth, "Mock profile created for user \(userID)")
        return created
    }

    func updateDisplayName(_ name: String) async throws -> Profile {
        let current = try await profile()
        return store(Profile(userId: current.userId,
                             displayName: Self.normalized(name),
                             createdAt: current.createdAt,
                             bio: current.bio))
    }

    func updateBio(_ bio: String) async throws -> Profile {
        let current = try await profile()
        return store(Profile(userId: current.userId,
                             displayName: current.displayName,
                             createdAt: current.createdAt,
                             bio: Self.normalizedBio(bio)))
    }

    private func store(_ updated: Profile) -> Profile {
        profiles[updated.userId] = updated
        logger.debug(.auth, "Mock profile updated for user \(updated.userId)")
        return updated
    }

    private func caller() throws -> String {
        guard let userID = identity.currentUserID else { throw AppError.sessionExpired }
        return userID
    }

    /// Laurel's `normalize`: trimmed, the default for a blank, the first `length.upperBound` code points. The API refuses
    /// a blank name with 400 before the service's default applies, so the fallback here mirrors the service rule only.
    private static func normalized(_ name: String) -> String {
        guard let trimmed = name.nonBlankTrimmed else { return AppConfig.DisplayName.backendDefault }
        return trimmed.prefix(codePoints: AppConfig.DisplayName.length.upperBound)
    }

    /// Laurel's `normalizeBio`: stripped, nothing for a blank, the first `maxLength` code points.
    private static func normalizedBio(_ bio: String) -> String? {
        bio.nonBlankTrimmed?.prefix(codePoints: AppConfig.About.maxLength)
    }
}
