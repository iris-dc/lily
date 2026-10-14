import Foundation
import Testing
@testable import lily

@MainActor
struct BlockListStoreTests {
    private let repository = FakeModerationRepository()
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()

    private func makeStore() -> BlockListStore {
        BlockListStore(repository: repository, identity: identity, logger: logger)
    }

    @Test func loadsOncePerUserAndExposesTheList() async {
        repository.blocked = ["u-9"]
        let store = makeStore()

        await store.loadIfNeeded()
        await store.loadIfNeeded()

        #expect(store.blockedUserIDs == ["u-9"] && repository.blocksRequestCount == 1)
        #expect(logger.messages(in: .groups, at: .info) == ["Block list loaded: 1 blocked"])
    }

    @Test func anotherUserIsLoadedAfresh() async {
        repository.blocked = ["u-9"]
        let store = makeStore()
        await store.loadIfNeeded()

        identity.currentUserID = "someone-else"
        repository.blocked = ["u-2"]
        await store.loadIfNeeded()

        #expect(store.blockedUserIDs == ["u-2"] && repository.blocksRequestCount == 2)
    }

    @Test func guestsCauseNoRequestAndHoldNoList() async {
        repository.blocked = ["u-9"]
        let store = makeStore()
        await store.loadIfNeeded()

        identity.currentUserID = nil
        await store.loadIfNeeded()

        #expect(store.blockedUserIDs.isEmpty && repository.blocksRequestCount == 1)
    }

    /// The load is a hint for cached rows: a failure is a warning, never a popup, and the next sync asks again.
    @Test func aFailedLoadIsLoggedNotShownAndRetried() async {
        repository.error = AppError.network
        let store = makeStore()

        await store.loadIfNeeded()
        #expect(store.blockedUserIDs.isEmpty)
        #expect(logger.messages(in: .groups, at: .warning).count == 1)
        #expect(logger.messages(in: .groups, at: .error).isEmpty)

        repository.error = nil
        repository.blocked = ["u-9"]
        await store.loadIfNeeded()
        #expect(store.blockedUserIDs == ["u-9"] && repository.blocksRequestCount == 2)
    }

    /// The backend answers the whole list; a list that moved under the store meanwhile is taken as answered, not
    /// merged with what the store held.
    @Test func blockingReplacesTheListWithTheBackendsAnswer() async throws {
        repository.blocked = ["u-1"]
        let store = makeStore()
        await store.loadIfNeeded()
        repository.blocked = ["u-2"]

        try await store.block(userID: "u-9")

        #expect(repository.blockedUserIDs == ["u-9"])
        #expect(store.blockedUserIDs == ["u-2", "u-9"])
        #expect(logger.messages(in: .groups, at: .info).contains("User u-9 blocked (2 blocked)"))
    }

    @Test func aRefusedBlockLeavesTheListAndRethrows() async {
        repository.blocked = ["u-1"]
        let store = makeStore()
        await store.loadIfNeeded()
        repository.error = AppError.blockLimitReached

        await #expect(throws: AppError.blockLimitReached) { try await store.block(userID: "u-9") }

        #expect(store.blockedUserIDs == ["u-1"])
        #expect(logger.messages(in: .groups, at: .info).count == 1, "nothing is logged as blocked")
    }

    @Test func signOutClearsTheListAndTheNextLoadAsksAgain() async {
        repository.blocked = ["u-9"]
        let store = makeStore()
        await store.loadIfNeeded()

        store.sessionDidEnd()
        #expect(store.blockedUserIDs.isEmpty)

        await store.loadIfNeeded()
        #expect(store.blockedUserIDs == ["u-9"] && repository.blocksRequestCount == 2)
    }

    /// A sign-out or a switch while `GET /api/blocks` is in flight: the answer is the previous user's list.
    @Test func anAnswerForAPreviousCallerIsDropped() async {
        repository.blocked = ["u-9"]
        repository.holdsRequests = true
        let store = makeStore()

        let load = Task { await store.loadIfNeeded() }
        await settle(until: { repository.blocksRequestCount == 1 })
        identity.currentUserID = "someone-else"
        repository.releaseRequests()
        await load.value

        #expect(store.blockedUserIDs.isEmpty)
        #expect(logger.messages(in: .cache, at: .debug).contains { $0.contains("Block list answer") })
    }

    @Test func aBlockAnswerForAPreviousCallerIsDropped() async throws {
        repository.holdsRequests = true
        let store = makeStore()

        let block = Task { try await store.block(userID: "u-9") }
        await settle(until: { repository.blockedUserIDs == ["u-9"] })
        identity.currentUserID = nil
        repository.releaseRequests()
        try await block.value

        #expect(store.blockedUserIDs.isEmpty)
        #expect(logger.messages(in: .cache, at: .debug).contains { $0.contains("Block answer") })
    }

    /// The shell cancels its sync when the scene phase changes while the list is in flight and starts another: the
    /// request is the store's own task, so it lands, and the new run joins it instead of asking again.
    @Test func aCancelledCallerNeitherLosesTheLoadNorDropsTheNextOne() async {
        repository.blocked = ["u-9"]
        repository.holdsRequests = true
        let store = makeStore()

        let cancelled = Task { await store.loadIfNeeded() }
        await settle(until: { repository.blocksRequestCount == 1 })
        cancelled.cancel()
        let replacement = Task { await store.loadIfNeeded() }
        await Task.yield()
        repository.releaseRequests()
        await cancelled.value
        await replacement.value

        #expect(store.blockedUserIDs == ["u-9"] && repository.blocksRequestCount == 1)
    }

    /// The shell cancels a sync whose phase changed; that is not a failure worth a warning.
    @Test func cancellationStaysQuiet() async {
        repository.error = CancellationError()
        let store = makeStore()

        await store.reload()

        #expect(store.blockedUserIDs.isEmpty && logger.messages(in: .groups, at: .warning).isEmpty)
        #expect(logger.messages(in: .groups, at: .debug).contains { $0.contains("cancelled") })
    }
}
