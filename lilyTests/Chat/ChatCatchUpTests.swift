import Foundation
import Testing
@testable import lily

@MainActor
struct ChatCatchUpTests {
    private let repository = FakeChatRepository()
    private let logger = SpyLogger()
    private let cache: InMemoryChatHistoryCache
    private let catchUp: ChatCatchUp

    init() {
        cache = InMemoryChatHistoryCache(logger: logger)
        catchUp = ChatCatchUp(repository: repository, cache: cache, logger: logger)
    }

    @Test func loadNewestCachesTheFirstPage() async throws {
        repository.newestPages = [.fixture([.fixture(id: "m1")], hasMore: true, epoch: 2)]

        let room = try await catchUp.loadNewest(groupID: "g", epoch: 1)

        #expect(room.restWatermark == "m1" && room.hasOlder && room.channelEpoch == 2 && cache.room(for: "g") == room)
    }

    @Test func catchUpPagesFromTheWatermarkUpToTheLimit() async throws {
        cache.store(.fixture(messages: [.fixture(id: "m1")]), for: "g")
        repository.newerPages = (2...5).map { .fixture([.fixture(id: "m\($0)")], hasMore: true) }

        let room = try await catchUp.catchUp(groupID: "g")

        #expect(repository.newerRequests.map(\.after) == ["m1", "m2", "m3"])
        #expect(room?.restWatermark == "m4" && room?.messages.count == 4)
    }

    @Test func catchUpStopsWhenAPageHasNoMore() async throws {
        cache.store(.fixture(messages: [.fixture(id: "m1")]), for: "g")
        repository.newerPages = [.fixture([.fixture(id: "m2")], hasMore: false)]

        _ = try await catchUp.catchUp(groupID: "g")

        #expect(repository.newerRequests.count == 1)
    }

    @Test func aRoomWithoutAWatermarkTakesTheNewestPage() async throws {
        cache.store(ChatRoomState(groupID: "g", channelEpoch: 1), for: "g")
        repository.newestPages = [.fixture([.fixture(id: "m1")])]

        let room = try await catchUp.catchUp(groupID: "g")

        #expect(repository.newestGroupIDs == ["g"] && room?.restWatermark == "m1")
    }

    @Test func anUncachedRoomHasNothingToCatchUp() async throws {
        #expect(try await catchUp.catchUp(groupID: "g") == nil)
        #expect(repository.newerRequests.isEmpty && repository.newestGroupIDs.isEmpty)
    }

    @Test func movedRoomsAreCaughtUpAFewAtATime() async {
        let ids = (1...5).map { "g\($0)" }
        for id in ids { cache.store(.fixture(groupID: id, messages: [.fixture(id: "m1", groupID: id)]), for: id) }
        let groups = ids.map { SportGroup.fixture(id: $0, lastMessageId: "m9", role: .member) }
        repository.holdsRequests = true

        let run = Task { await catchUp.catchUpMovedRooms(groups, openRoomID: nil, maxConcurrent: 2) }
        await settle(until: { repository.newerRequests.count == 2 })
        await Task.yield()
        #expect(repository.newerRequests.count == 2, "never more than the limit in flight")
        repository.releaseRequests()
        await run.value

        #expect(Set(repository.newerRequests.map(\.groupID)) == Set(ids))
    }

    @Test func theOpenRoomIsAlwaysCaughtUpAndFailuresStayWarnings() async {
        cache.store(.fixture(groupID: "open", messages: [.fixture(id: "m1", groupID: "open")]), for: "open")
        repository.pageError = AppError.chatUnavailable

        await catchUp.catchUpMovedRooms([.fixture(id: "open", lastMessageId: "m1", role: .member)],
                                        openRoomID: "open",
                                        maxConcurrent: 3)

        #expect(repository.newerRequests.map(\.groupID) == ["open"])
        #expect(logger.messages(in: .chat, at: .warning).contains { $0.contains("Catch-up failed for group open") })
    }
}
