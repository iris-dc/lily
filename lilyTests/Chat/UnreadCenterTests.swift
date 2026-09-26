import Foundation
import Testing
@testable import lily

@MainActor
struct UnreadCenterTests {
    private let center = UnreadCenter()

    /// Without local knowledge the snapshot rules: its flags are taken, and a group not in it is not the caller's.
    @Test func theMineLoadSetsTheFlagsOfGroupsNothingIsKnownAbout() {
        center.markUnread(groupID: "stale", messageID: "m1")

        center.apply(groups: [.fixture(id: "a", role: .member, hasUnread: true), .fixture(id: "b", role: .member)])

        #expect(center.unreadGroupIDs == ["a"] && center.count == 1)
        #expect(center.hasUnread(groupID: "a") && !center.hasUnread(groupID: "stale"))
    }

    /// The snapshot was read before the room was: a room read here up to its newest message stays read, one with a
    /// message newer than what was read here lights up.
    @Test func theMineLoadCannotBringBackARoomReadHere() {
        center.markUnread(groupID: "a", messageID: "m5")
        center.markRead(groupID: "a", upTo: "m5")
        center.markRead(groupID: "b", upTo: "m5")

        center.apply(groups: [.fixture(id: "a", lastMessageId: "m5", role: .member, hasUnread: true),
                              .fixture(id: "b", lastMessageId: "m6", role: .member, hasUnread: true)])

        #expect(center.unreadGroupIDs == ["b"])
    }

    /// A live message the snapshot predates keeps its dot; one the snapshot's read marker already covers was read
    /// elsewhere and loses it.
    @Test func theMineLoadKeepsALiveMarkNewerThanItsReadMarker() {
        center.markUnread(groupID: "a", messageID: "m7")
        center.markUnread(groupID: "b", messageID: "m7")

        center.apply(groups: [.fixture(id: "a", lastMessageId: "m6", role: .member, lastReadMessageId: "m6"),
                              .fixture(id: "b", lastMessageId: "m7", role: .member, lastReadMessageId: "m7")])
        #expect(center.unreadGroupIDs == ["a"])

        center.apply(groups: [.fixture(id: "a", lastMessageId: "m7", role: .member, lastReadMessageId: "m7"),
                              .fixture(id: "b", lastMessageId: "m7", role: .member, lastReadMessageId: "m7")])
        #expect(center.unreadGroupIDs.isEmpty, "the dropped live mark does not return")
    }

    @Test func liveMarksAndReadsMoveTheDot() {
        center.markUnread(groupID: "a", messageID: "m1")
        center.markUnread(groupID: "a", messageID: "m2")
        center.markUnread(groupID: "b", messageID: "m1")
        #expect(center.count == 2)

        center.markRead(groupID: "a")
        #expect(center.unreadGroupIDs == ["b"])
    }

    @Test func signOutClearsEverything() {
        center.markUnread(groupID: "a", messageID: "m9")
        center.markRead(groupID: "b", upTo: "m9")
        center.sessionDidEnd()
        #expect(center.unreadGroupIDs.isEmpty)

        center.apply(groups: [.fixture(id: "b", lastMessageId: "m1", role: .member, hasUnread: true)])
        #expect(center.unreadGroupIDs == ["b"], "the next user's snapshot is not judged against the last one's reads")
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
