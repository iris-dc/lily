import Foundation
import Testing
@testable import lily

/// The mock mirrors Laurel: a profile created with the default name on the first read, a rename trimmed and cut to the
/// cap, a blank falling back to the default, a guest refused.
@MainActor
struct MockProfileRepositoryTests {
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let now = Date(timeIntervalSince1970: 1_757_584_800)

    private func makeRepository() -> MockProfileRepository {
        MockProfileRepository(identity: identity, logger: logger, now: { now })
    }

    @Test func theFirstReadCreatesTheProfileWithTheDefaultName() async throws {
        let repository = makeRepository()

        let profile = try await repository.profile()
        let again = try await repository.profile()

        let expected = Profile(userId: TestFixtures.user.id, displayName: AppConfig.DisplayName.backendDefault, createdAt: now)
        #expect(profile == expected)
        #expect(again == profile, "the second read answers the same profile")
        #expect(logger.count(in: .auth, at: .debug, mentioning: "Mock profile created", TestFixtures.user.id) == 1)
    }

    @Test func anUpdateTrimsAndCapsAtTheLimitAndKeepsTheName() async throws {
        let repository = makeRepository()
        let limit = AppConfig.DisplayName.length.upperBound
        let long = String(repeating: "🏓", count: limit + 1)

        let updated = try await repository.updateDisplayName("  \(long)  ")
        let read = try await repository.profile()
        let renamed = try await repository.updateDisplayName(" Alex Kim ")

        #expect(updated.displayName == String(repeating: "🏓", count: limit), "cut in code points, never inside one")
        #expect(updated.createdAt == now && updated.userId == TestFixtures.user.id)
        #expect(read == updated)
        #expect(renamed.displayName == "Alex Kim")
    }

    @Test func aBlankUpdateFallsBackToTheDefaultName() async throws {
        let repository = makeRepository()
        _ = try await repository.updateDisplayName("Alex Kim")

        let updated = try await repository.updateDisplayName("   ")

        #expect(updated.displayName == AppConfig.DisplayName.backendDefault)
    }

    @Test func aGuestIsRefusedWithSessionExpired() async {
        identity.currentUserID = nil
        let repository = makeRepository()

        await #expect(throws: AppError.sessionExpired) { try await repository.profile() }
        await #expect(throws: AppError.sessionExpired) { try await repository.updateDisplayName("Alex") }
    }

    /// Two mock users (`-mock-user-id` on two simulators) keep their own names.
    @Test func profilesAreKeptPerUser() async throws {
        let repository = makeRepository()
        _ = try await repository.updateDisplayName("Alex Kim")
        identity.currentUserID = "someone-else"

        let other = try await repository.profile()

        #expect(other.userId == "someone-else" && other.displayName == AppConfig.DisplayName.backendDefault)
    }
}
