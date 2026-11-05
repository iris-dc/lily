import Foundation
import Testing
@testable import lily

/// The store's bio write: through to the backend, the profile replaced, the snapshot kept, a lost answer settled by
/// reading the profile back; the main suite is at its type-body limit.
@MainActor
struct ProfileStoreBioTests {
    private let repository = FakeProfileRepository()
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let snapshots = InMemoryListSnapshotStore()

    private func makeStore() -> ProfileStore {
        ProfileStore(repository: repository, identity: identity, snapshots: snapshots, logger: logger)
    }

    @Test func aBioUpdateWritesThroughAndReplacesTheProfile() async throws {
        let store = makeStore()
        await store.loadIfNeeded()
        #expect(store.bio == nil)

        let updated = try await store.updateBio(to: " Padel on Sundays. ")

        #expect(repository.updatedBios == [" Padel on Sundays. "], "the store sends what it is given; the editor trims")
        #expect(updated.bio == "Padel on Sundays." && store.bio == "Padel on Sundays.")
        #expect(store.displayName == AppConfig.DisplayName.backendDefault, "the name is untouched")
        #expect(snapshots.load(Profile.self, for: ListSnapshotKey(list: "profile", userID: TestFixtures.user.id)) == updated)
        let lines = logger.messages(in: .auth, at: .info).mentioning("Bio updated", TestFixtures.user.id)
        #expect(lines.count == 1 && !lines[0].contains("Padel"), "ids only, never the text")
    }

    /// A lost answer on a bio write is settled like a rename's: the profile read back shows the text stripped, or no
    /// bio at all for a clear.
    @Test(arguments: [("Padel on Sundays.", Optional("Padel on Sundays.")), ("   ", nil)])
    func aBioWriteWithAnUnknownOutcomeIsSettledByReadingTheProfileBack(text: String, stored: String?) async throws {
        let store = makeStore()
        await store.loadIfNeeded()
        repository.updateResult = .failure(AppError.aboutUpdateFailed)
        repository.profileResult = .success(.fixture(bio: stored))

        let updated = try await store.updateBio(to: text)

        #expect(updated.bio == stored && store.bio == stored && repository.profileCallCount == 2)
        #expect(logger.count(in: .auth, at: .info, mentioning: "Bio update landed despite") == 1)
    }
}
