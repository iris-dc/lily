import Foundation
@testable import lily

/// Scriptable `ProfileRepository`: every read answers `profileResult`, every update is recorded and answers
/// `updateResult`, or the text as the backend would store it; `holdsRequests` parks a call until `releaseRequests()`.
@MainActor
final class FakeProfileRepository: ProfileRepository, HoldsRequests {
    var profileResult: Result<Profile, any Error> = .success(.fixture())
    /// The update's answer when set; otherwise the request's text comes back as the stored one.
    var updateResult: Result<Profile, any Error>?
    let hold = RequestHold()
    private(set) var profileCallCount = 0
    private(set) var updatedNames: [String] = []
    private(set) var updatedBios: [String] = []

    func profile() async throws -> Profile {
        profileCallCount += 1
        try await hold.waitOrThrow()
        return try profileResult.get()
    }

    func updateDisplayName(_ name: String) async throws -> Profile {
        updatedNames.append(name)
        try await hold.waitOrThrow()
        if let updateResult { return try updateResult.get() }
        return .fixture(displayName: name)
    }

    /// Without a scripted answer the bio comes back stripped, nothing for a blank, as Laurel stores it.
    func updateBio(_ bio: String) async throws -> Profile {
        updatedBios.append(bio)
        try await hold.waitOrThrow()
        if let updateResult { return try updateResult.get() }
        return .fixture(bio: bio.nonBlankTrimmed)
    }
}

extension Profile {
    /// The caller's profile as the backend creates it: the default name and no bio, unless given.
    static func fixture(userId: String = TestFixtures.user.id,
                        displayName: String = AppConfig.DisplayName.backendDefault,
                        createdAt: Date = Date(timeIntervalSince1970: 1_757_584_800),
                        bio: String? = nil) -> Profile {
        Profile(userId: userId, displayName: displayName, createdAt: createdAt, bio: bio)
    }
}
