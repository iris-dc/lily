import Foundation
import Testing
@testable import lily

@MainActor
struct UnreadCenterTests {
    private let center = UnreadCenter()

    @Test func theMineLoadReplacesTheSet() {
        center.markUnread(groupID: "stale")

        center.apply(groups: [.fixture(id: "a", role: .member, hasUnread: true), .fixture(id: "b", role: .member)])

        #expect(center.unreadGroupIDs == ["a"] && center.count == 1)
        #expect(center.hasUnread(groupID: "a") && !center.hasUnread(groupID: "stale"))
    }

    @Test func liveMarksAndReadsMoveTheDot() {
        center.markUnread(groupID: "a")
        center.markUnread(groupID: "a")
        center.markUnread(groupID: "b")
        #expect(center.count == 2)

        center.markRead(groupID: "a")
        #expect(center.unreadGroupIDs == ["b"])
    }

    @Test func signOutClearsEverything() {
        center.markUnread(groupID: "a")
        center.sessionDidEnd()
        #expect(center.unreadGroupIDs.isEmpty)
    }
}

@MainActor
struct InMemoryChatHistoryCacheTests {
    private let logger = SpyLogger()

    @Test func storesDropsCompactsAndClears() {
        let cache = InMemoryChatHistoryCache(limit: 2, logger: logger)
        let room = ChatRoomState.fixture(messages: [.fixture(id: "m1"), .fixture(id: "m2"), .fixture(id: "m3")])

        cache.store(room, for: "g")
        #expect(cache.room(for: "g") == room && cache.cachedGroupIDs == ["g"])

        cache.compact(groupID: "g")
        #expect(cache.room(for: "g")?.messages.map(\.id) == ["m2", "m3"])

        cache.update(groupID: "g") { $0.insert(.fixture(id: "m4")) }
        #expect(cache.room(for: "g")?.displayMaxID == "m4")
        cache.update(groupID: "missing") { $0.insert(.fixture(id: "m4")) }
        #expect(cache.room(for: "missing") == nil)

        cache.drop(groupID: "g", reason: "left")
        #expect(cache.room(for: "g") == nil)
        #expect(logger.messages(in: .cache, at: .info) == ["Room cache dropped for group g (left)"])
        cache.drop(groupID: "g", reason: "again")
        #expect(logger.messages(in: .cache, at: .info).count == 1, "dropping nothing logs nothing")
    }

    @Test func signOutClearsEveryRoom() {
        let cache = InMemoryChatHistoryCache(logger: logger)
        cache.store(.fixture(groupID: "a"), for: "a")
        cache.store(.fixture(groupID: "b"), for: "b")

        cache.sessionDidEnd()

        #expect(cache.cachedGroupIDs.isEmpty)
    }
}
