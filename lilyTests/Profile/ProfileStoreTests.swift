import Foundation
import Testing
@testable import lily

/// The caller's name as the backend knows it: loaded once per session, never shown failing, replaced by a rename,
/// cleared with the session; logs carry the user id and never the name.
@MainActor
struct ProfileStoreTests {
    private let repository = FakeProfileRepository()
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let snapshots = InMemoryListSnapshotStore()

    private func makeStore() -> ProfileStore {
        ProfileStore(repository: repository, identity: identity, snapshots: snapshots, logger: logger)
    }

    private var snapshotKey: ListSnapshotKey {
        ListSnapshotKey(list: AppConfig.Lists.profileSnapshot, userID: TestFixtures.user.id)
    }

    /// The last profile shown is the next launch's first frame, and a hint only: the load still runs once and its
    /// answer replaces it; a rename writes the snapshot too; a guest's launch reads none.
    @Test func startsFromTheSnapshotAndStillLoadsOnce() async throws {
        snapshots.seed(Profile.fixture(displayName: "Alex Kim"), for: snapshotKey)
        repository.profileResult = .success(.fixture(displayName: "Alex K."))
        let store = makeStore()
        #expect(store.displayName == "Alex Kim" && !store.isLoading, "the snapshot is the first frame")

        await store.loadIfNeeded()
        #expect(repository.profileCallCount == 1)
        #expect(store.displayName == "Alex K.", "the backend's answer replaces the snapshot")
        #expect(snapshots.load(Profile.self, for: snapshotKey)?.displayName == "Alex K.")
        await store.loadIfNeeded()
        #expect(repository.profileCallCount == 1, "the answer, not the snapshot, counts as loaded")

        repository.updateResult = .success(.fixture(displayName: "Alexandra"))
        _ = try await store.rename(to: "Alexandra")
        #expect(snapshots.load(Profile.self, for: snapshotKey)?.displayName == "Alexandra")
        #expect(snapshots.saveCount == 2)

        identity.currentUserID = nil
        #expect(makeStore().displayName == nil, "a guest's launch reads no snapshot")
    }

    /// A user who signs in after launch finds their snapshot when Profile opens, for the frames the load takes.
    @Test func aSignInAfterLaunchFindsItsSnapshotOnOpen() async {
        identity.currentUserID = nil
        let store = makeStore()
        snapshots.seed(Profile.fixture(displayName: "Alex Kim"), for: snapshotKey)
        repository.holdsRequests = true
        identity.currentUserID = TestFixtures.user.id

        let load = Task { await store.loadIfNeeded() }
        await settle(until: { repository.isHolding })
        #expect(store.displayName == "Alex Kim" && store.isLoading, "the snapshot shows while the load is out")
        repository.releaseRequests()
        await load.value
        #expect(repository.profileCallCount == 1)
    }

    @Test func loadsOncePerUserAndExposesTheName() async {
        repository.profileResult = .success(.fixture(displayName: "Alex Kim"))
        let store = makeStore()

        await store.loadIfNeeded()
        await store.loadIfNeeded()

        #expect(repository.profileCallCount == 1)
        #expect(store.displayName == "Alex Kim" && !store.isDefaultName && !store.isLoading)
        #expect(logger.count(in: .cache, at: .debug, mentioning: "Profile reused") == 1)
        #expect(logger.count(in: .auth, at: .info, mentioning: "Profile loaded", TestFixtures.user.id) == 1)
        identity.currentUserID = "someone-else"
        await store.loadIfNeeded()
        #expect(repository.profileCallCount == 2)
    }

    @Test func guestsHaveNoProfileAndCauseNoRequest() async {
        let store = makeStore()
        await store.loadIfNeeded()
        #expect(store.profile != nil)

        identity.currentUserID = nil
        await store.loadIfNeeded()

        #expect(store.profile == nil && store.displayName == nil && repository.profileCallCount == 1)
    }

    /// The store has no error centre at all: a failed load is a warning line, and the next `loadIfNeeded` asks again.
    @Test func aFailedLoadIsLoggedNotShownAndRetried() async {
        repository.profileResult = .failure(AppError.network)
        let store = makeStore()

        await store.loadIfNeeded()
        #expect(store.profile == nil && !store.isLoading)
        #expect(logger.count(in: .auth, at: .warning, mentioning: "Loading the profile failed") == 1)

        repository.profileResult = .success(.fixture())
        await store.loadIfNeeded()
        #expect(store.profile != nil && repository.profileCallCount == 2)
    }

    @Test func aRenameWritesThroughAndReplacesTheProfile() async throws {
        let store = makeStore()
        await store.loadIfNeeded()
        repository.updateResult = .success(.fixture(displayName: "Alex Kim"))

        let updated = try await store.rename(to: "Alex Kim")

        #expect(repository.updatedNames == ["Alex Kim"])
        #expect(updated.displayName == "Alex Kim" && store.displayName == "Alex Kim" && !store.isDefaultName)
        let lines = logger.messages(in: .auth, at: .info).mentioning("Display name updated", TestFixtures.user.id)
        #expect(lines.count == 1 && !lines[0].contains("Alex"), "ids only, never the name")
    }

    @Test func aGuestCannotRename() async {
        identity.currentUserID = nil
        let store = makeStore()

        await #expect(throws: AppError.sessionExpired) { try await store.rename(to: "Alex Kim") }
        #expect(repository.updatedNames.isEmpty)
    }

    /// A lost connection or a 5xx leaves the PUT's outcome unknown, and Laurel commits before it answers: the profile
    /// is read back, and a rename it shows is the answer, with nothing to report.
    @Test(arguments: [AppError.network, .profileUpdateFailed])
    func anUnknownOutcomeIsSettledByReadingTheProfileBack(failure: AppError) async throws {
        let store = makeStore()
        await store.loadIfNeeded()
        repository.updateResult = .failure(failure)
        repository.profileResult = .success(.fixture(displayName: "Alex Kim"))

        let updated = try await store.rename(to: "Alex Kim")

        #expect(updated.displayName == "Alex Kim" && store.displayName == "Alex Kim" && !store.isDefaultName)
        #expect(repository.profileCallCount == 2, "the load, then the one read-back")
        #expect(logger.count(in: .auth, at: .info, mentioning: "Rename landed despite") == 1)
        #expect(logger.count(in: .auth, at: .info, mentioning: "Display name updated", TestFixtures.user.id) == 1)
    }

    @Test func anUnknownOutcomeWhoseReadBackShowsAnotherNameIsThrown() async {
        let store = makeStore()
        await store.loadIfNeeded()
        repository.updateResult = .failure(AppError.network)

        await #expect(throws: AppError.network) { try await store.rename(to: "Alex Kim") }

        #expect(repository.profileCallCount == 2 && store.isDefaultName, "read back once; the header keeps the backend's name")
        #expect(logger.hasLine(in: .auth, at: .debug, mentioning: "Rename did not land"))
    }

    @Test func anUnknownOutcomeWhoseReadBackFailsKeepsTheFailure() async {
        let store = makeStore()
        repository.updateResult = .failure(AppError.network)
        repository.profileResult = .failure(AppError.profileUnavailable)

        await #expect(throws: AppError.network) { try await store.rename(to: "Alex Kim") }

        #expect(store.profile == nil)
        #expect(logger.count(in: .auth, at: .warning, mentioning: "Could not check whether the rename landed") == 1)
    }

    /// A refusal (a blocked word, the terms gate) says the name was not stored: nothing to read back.
    @Test func aRefusalIsNotReadBack() async {
        let store = makeStore()
        repository.updateResult = .failure(AppError.contentRejected)

        await #expect(throws: AppError.contentRejected) { try await store.rename(to: "Something rude") }

        #expect(repository.profileCallCount == 0)
    }

    /// A sign-out while `GET /api/profile` is in flight: the answer is the previous user's, not a guest's.
    @Test func anAnswerForAPreviousCallerIsDropped() async {
        repository.holdsRequests = true
        let store = makeStore()

        let load = Task { await store.loadIfNeeded() }
        await settle(until: { store.isLoading })
        identity.currentUserID = nil
        store.sessionDidEnd()
        repository.releaseRequests()
        await load.value

        #expect(store.profile == nil && !store.isLoading)
        #expect(logger.hasLine(in: .cache, at: .debug, mentioning: "Profile answer", "previous caller"))
    }

    @Test func aRenameAnswerForAPreviousCallerIsDropped() async throws {
        repository.holdsRequests = true
        let store = makeStore()

        let rename = Task { try await store.rename(to: "Alex Kim") }
        await settle(until: { repository.isHolding })
        identity.currentUserID = nil
        repository.releaseRequests()
        _ = try await rename.value

        #expect(store.profile == nil)
        #expect(logger.hasLine(in: .cache, at: .debug, mentioning: "Rename answer", "previous caller"))
    }

    /// Profile opened on a slow network and the user renamed before `GET /api/profile` answered: the rename is the newer
    /// name, so the read's answer is dropped instead of putting the default back for the rest of the session.
    @Test func aRenameLandingWhileTheLoadIsOutWins() async throws {
        repository.holdsRequests = true
        let store = makeStore()

        let load = Task { await store.loadIfNeeded() }
        await settle(until: { repository.isHolding })
        repository.holdsRequests = false
        _ = try await store.rename(to: "Alex Kim")
        repository.releaseRequests()
        await load.value

        #expect(store.displayName == "Alex Kim" && !store.isDefaultName && repository.profileCallCount == 1)
        #expect(logger.hasLine(in: .cache, at: .debug, mentioning: "Profile answer superseded by a rename"))
    }

    @Test func signOutClearsTheProfile() async {
        let store = makeStore()
        await store.loadIfNeeded()

        store.sessionDidEnd()

        #expect(store.profile == nil && !store.isDefaultName)
        #expect(logger.count(in: .cache, at: .debug, mentioning: "Profile cleared on sign-out") == 1)
        await store.loadIfNeeded()
        #expect(repository.profileCallCount == 2, "the next load asks again")
    }

    @Test func isDefaultNameFollowsTheBackendsDefault() async {
        let store = makeStore()
        await store.loadIfNeeded()
        #expect(store.isDefaultName, "the fixture starts as the backend's default")

        repository.profileResult = .success(.fixture(displayName: "Alex"))
        store.sessionDidEnd()
        await store.loadIfNeeded()

        #expect(!store.isDefaultName && store.displayName == "Alex")
    }

    @Test func concurrentLoadsCollapseIntoOne() async {
        repository.holdsRequests = true
        let store = makeStore()

        let first = Task { await store.loadIfNeeded() }
        await settle(until: { store.isLoading })
        let second = Task { await store.loadIfNeeded() }
        await Task.yield()
        repository.releaseRequests()
        await first.value
        await second.value

        #expect(repository.profileCallCount == 1 && store.profile != nil && !store.isLoading)
    }
}
