import Foundation
import Testing
@testable import lily

/// Warming the Chats list's top rooms: only rooms without history, up to the limit, a few at a time, never twice at
/// once, and a failed warm-up waits out the retry interval instead of re-asking on every appearance.
@MainActor
struct ChatCatchUpPreloadTests {
    private let repository = FakeChatRepository()
    private let logger = SpyLogger()
    private let clock = DateClock()
    private let cache: InMemoryChatHistoryCache
    private let catchUp: ChatCatchUp

    init() {
        cache = InMemoryChatHistoryCache(logger: logger)
        catchUp = ChatCatchUp(repository: repository, cache: cache, logger: logger, now: { [clock] in clock.now })
    }

    private func groups(_ ids: [String]) -> [SportGroup] {
        ids.map { .fixture(id: $0, role: .member) }
    }

    /// A room already holding history costs nothing, and the limit caps the requests whatever the list's length.
    @Test func warmsOnlyRoomsWithoutHistoryUpToTheLimit() async {
        cache.store(.fixture(groupID: "g2", messages: [.fixture(id: "m1", groupID: "g2")]), for: "g2")
        repository.newestPages = [.fixture([]), .fixture([])]

        await catchUp.preloadRooms(groups(["g1", "g2", "g3", "g4"]), limit: 2, maxConcurrent: 3)

        #expect(Set(repository.newestGroupIDs) == ["g1", "g3"], "the cached room is skipped and the limit holds")
        #expect(cache.room(for: "g1")?.hasHistory == true && cache.room(for: "g3")?.hasHistory == true)
        #expect(cache.room(for: "g4") == nil, "the room past the limit is not touched")
    }

    @Test func warmsAFewAtATime() async {
        let ids = (1...5).map { "g\($0)" }
        repository.newestPages = ids.map { _ in .fixture([]) }
        repository.holdsRequests = true

        let run = Task { await catchUp.preloadRooms(groups(ids), limit: 5, maxConcurrent: 2) }
        await settle(until: { repository.newestGroupIDs.count == 2 })
        await Task.yield()
        #expect(repository.newestGroupIDs.count == 2, "never more than the limit in flight")
        repository.releaseRequests()
        await run.value

        #expect(Set(repository.newestGroupIDs) == Set(ids))
    }

    /// The Chats list reappearing while a warm-up still runs asks nothing twice for the same room.
    @Test func aRoomBeingWarmedIsNotAskedTwice() async {
        repository.newestPages = [.fixture([])]
        repository.holdsRequests = true

        let first = Task { await catchUp.preloadRooms(groups(["g1"]), limit: 5, maxConcurrent: 2) }
        await settle(until: { repository.newestGroupIDs.count == 1 })
        await catchUp.preloadRooms(groups(["g1"]), limit: 5, maxConcurrent: 2)
        repository.releaseRequests()
        await first.value

        #expect(repository.newestGroupIDs == ["g1"], "the second appearance joins nothing and asks nothing")
    }

    /// A dead backend costs one request per room per `preloadRetryInterval`, not one per tab visit; the stub the
    /// failed page left keeps a live line's place and does not count as history.
    @Test func aFailedWarmUpWaitsOutTheRetryInterval() async {
        repository.pageError = AppError.chatUnavailable

        await catchUp.preloadRooms(groups(["g1"]), limit: 5, maxConcurrent: 2)
        #expect(repository.newestGroupIDs == ["g1"])
        #expect(logger.messages(in: .chat, at: .warning).contains { $0.contains("Warm-up failed for room g1") })

        await catchUp.preloadRooms(groups(["g1"]), limit: 5, maxConcurrent: 2)
        #expect(repository.newestGroupIDs == ["g1"], "within the interval nothing is re-asked")

        clock.advance(by: AppConfig.Chat.preloadRetryInterval)
        repository.pageError = nil
        repository.newestPages = [.fixture([])]
        await catchUp.preloadRooms(groups(["g1"]), limit: 5, maxConcurrent: 2)

        #expect(repository.newestGroupIDs == ["g1", "g1"] && cache.room(for: "g1")?.hasHistory == true)
    }

    /// The warm-up bookkeeping is the signed-out user's: a sign-out clears the failure stamps, so the next account's
    /// shared room is not made to wait out a stranger's interval.
    @Test func aSignOutClearsTheFailureStamps() async {
        repository.pageError = AppError.chatUnavailable
        await catchUp.preloadRooms(groups(["g1"]), limit: 5, maxConcurrent: 2)
        #expect(repository.newestGroupIDs == ["g1"])

        catchUp.sessionDidEnd()
        repository.pageError = nil
        repository.newestPages = [.fixture([])]
        await catchUp.preloadRooms(groups(["g1"]), limit: 5, maxConcurrent: 2)

        #expect(repository.newestGroupIDs == ["g1", "g1"], "the stamp did not survive the session")
    }
}
