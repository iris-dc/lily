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

        let room = try #require(try await catchUp.loadNewest(groupID: "g", epoch: 1))

        #expect(room.restWatermark == "m1" && room.hasOlder && room.channelEpoch == 2 && cache.room(for: "g") == room)
    }

    /// The room is cached as a stub before the first page is asked for, so a live message has somewhere to land.
    @Test func aLiveMessageArrivingDuringTheFirstPageSurvives() async throws {
        repository.newestPages = [.fixture([.fixture(id: "m1"), .fixture(id: "m2")], hasMore: true)]
        repository.holdsRequests = true

        let load = Task { try await catchUp.loadNewest(groupID: "g", epoch: 1) }
        await settle(until: { repository.newestGroupIDs.count == 1 })
        cache.update(groupID: "g") { $0.insert(.fixture(id: "m3")) }
        repository.releaseRequests()
        let room = try #require(try await load.value)

        #expect(room.messages.map(\.id) == ["m1", "m2", "m3"] && room.hasHistory && room.hasOlder)
        #expect(room.restWatermark == "m2", "a live message never moves the watermark")
    }

    /// Every page is merged into the room as the cache holds it, never into a copy taken before the request.
    @Test func aLiveMessageArrivingDuringACatchUpSurvives() async throws {
        cache.store(.fixture(messages: [.fixture(id: "m1")]), for: "g")
        repository.newerPages = [.fixture([.fixture(id: "m2")])]
        repository.holdsRequests = true

        let run = Task { try await catchUp.catchUp(groupID: "g") }
        await settle(until: { repository.newerRequests.count == 1 })
        cache.update(groupID: "g") { $0.insert(.fixture(id: "m3")) }
        repository.releaseRequests()
        let room = try #require(try await run.value)

        #expect(room.messages.map(\.id) == ["m1", "m2", "m3"] && room.restWatermark == "m2")
        #expect(cache.room(for: "g") == room)
    }

    /// The caller's own `member_left` arrives while a page is in flight: the room the controller dropped stays dropped.
    @Test func aRoomDroppedDuringACatchUpStaysDropped() async throws {
        let harness = RealtimeHarness()
        harness.groups.result = .success([.fixture(id: "g1", role: .member)])
        harness.cache.store(.fixture(groupID: "g1", messages: [.fixture(id: "m1", groupID: "g1")]), for: "g1")
        await harness.connect()
        harness.chat.newerPages = [.fixture([.fixture(id: "m2", groupID: "g1")])]
        harness.chat.holdsRequests = true
        let room = RealtimeChannel.room(groupID: "g1", epoch: 1)

        let run = Task { try await harness.catchUp.catchUp(groupID: "g1") }
        await settle(until: { harness.chat.newerRequests.count == 1 })
        harness.transport.post(.message(.fixture(id: "m3", groupID: "g1")), to: room)
        await settle(until: { harness.cache.room(for: "g1")?.messages.count == 2 })
        harness.transport.post(.memberLeft(groupID: "g1", userID: TestFixtures.user.id, channelEpoch: 2, memberCount: 4),
                               to: room)
        await settle(until: { harness.cache.room(for: "g1") == nil })
        harness.chat.releaseRequests()

        #expect(try await run.value == nil)
        #expect(harness.cache.room(for: "g1") == nil, "the page must not resurrect a room the caller lost")
    }

    @Test func catchUpPagesFromTheWatermarkUpToTheLimit() async throws {
        cache.store(.fixture(messages: [.fixture(id: "m1")]), for: "g")
        repository.newerPages = (2...5).map { .fixture([.fixture(id: "m\($0)")], hasMore: true) }

        let room = try await catchUp.catchUp(groupID: "g")

        #expect(repository.newerRequests.map(\.after) == ["m1", "m2", "m3"])
        #expect(room?.restWatermark == "m4" && room?.messages.count == 4)
    }

    /// A page of hidden or already-held messages names where to continue; the watermark follows it, not the items.
    @Test func catchUpContinuesFromTheCursorWhenAPageShowsNothingNew() async throws {
        cache.store(.fixture(messages: [.fixture(id: "m1")]), for: "g")
        repository.newerPages = [.fixture([], hasMore: true, nextAfter: "m5"), .fixture([.fixture(id: "m6")])]

        let room = try await catchUp.catchUp(groupID: "g")

        #expect(repository.newerRequests.map(\.after) == ["m1", "m5"])
        #expect(room?.restWatermark == "m6" && room?.messages.map(\.id) == ["m1", "m6"])
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

    /// The second resume pass names its rooms: a watermark the first pass already moved is no reason to skip one.
    @Test func namedRoomsAreCaughtUpWhateverTheirWatermarkSays() async {
        cache.store(.fixture(groupID: "g1", messages: [.fixture(id: "m9", groupID: "g1")]), for: "g1")
        cache.store(.fixture(groupID: "g2", messages: [.fixture(id: "m9", groupID: "g2")]), for: "g2")

        await catchUp.catchUpMovedRooms([.fixture(id: "g1", lastMessageId: "m9", role: .member)],
                                        openRoomID: nil,
                                        maxConcurrent: 2)
        #expect(repository.newerRequests.isEmpty, "nothing moved past the watermark")

        await catchUp.catchUpRooms(["g1", "g2"], maxConcurrent: 2)

        #expect(repository.newerRequests.map { "\($0.groupID)/\($0.after)" } == ["g1/m9", "g2/m9"])
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
