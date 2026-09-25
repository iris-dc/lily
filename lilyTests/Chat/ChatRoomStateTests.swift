import Foundation
import Testing
@testable import lily

struct ChatRoomStateTests {
    private let first = ChatMessage.fixture(id: "m1")
    private let second = ChatMessage.fixture(id: "m2", clientMessageID: "c-2")
    private let third = ChatMessage.fixture(id: "m3")

    @Test func insertKeepsIdOrderAndDedupes() {
        var room = ChatRoomState(groupID: "g", channelEpoch: 1)

        let inserted = [room.insert(third), room.insert(first), room.insert(second)]
        let duplicate = room.insert(second)
        #expect(inserted == [true, true, true])
        #expect(!duplicate, "a duplicate changes nothing")

        #expect(room.messages.map(\.id) == ["m1", "m2", "m3"])
        #expect(room.displayMaxID == "m3" && room.oldestID == "m1")
        #expect(room.contains(clientMessageID: "c-2") && !room.contains(clientMessageID: "c-9"))
    }

    /// The watermark is the REST anchor: a live message never moves it, so a lost publish behind it is still fetched.
    @Test func restWatermarkMovesOnlyOnNewestAndNewerPages() {
        var room = ChatRoomState(groupID: "g", channelEpoch: 1)
        room.insert(third)
        #expect(room.restWatermark == nil && room.displayMaxID == "m3")

        room.applyNewest(.fixture([first], hasMore: true, epoch: 2))
        #expect(room.restWatermark == "m1" && room.hasOlder && room.hasHistory && room.channelEpoch == 2)

        room.applyOlder(.fixture([.fixture(id: "m0")], hasMore: false))
        #expect(room.restWatermark == "m1" && !room.hasOlder && room.oldestID == "m0")

        room.applyNewer(.fixture([second], hasMore: false))
        #expect(room.restWatermark == "m2" && room.displayMaxID == "m3")

        room.applyNewer(.fixture([], hasMore: false))
        #expect(room.restWatermark == "m2", "an empty page leaves the watermark")
        room.applyNewer(.fixture([first], hasMore: false))
        #expect(room.restWatermark == "m2", "the watermark never moves backwards")
    }

    /// AppSync delivers unordered: the tombstone may land first and must still win.
    @Test func deleteBeforeInsert() {
        var room = ChatRoomState(groupID: "g", channelEpoch: 1)

        room.markDeleted(id: "m2")
        room.insert(second)

        #expect(room.messages.map(\.isDeleted) == [true])
        #expect(room.messages.first?.text == nil)
        #expect(room.tombstonedIDs == ["m2"])

        room.insert(first)
        room.markDeleted(id: "m1")
        #expect(room.messages.first?.isDeleted == true)
        let tombstoneAgain = room.insert(first.markingDeleted())
        #expect(!tombstoneAgain, "already a tombstone")
    }

    @Test func aDeletedFormReplacesTheLiveOne() {
        var room = ChatRoomState(groupID: "g", channelEpoch: 1)
        room.insert(first)

        let replaced = room.insert(first.markingDeleted())
        #expect(replaced && room.messages.first?.isDeleted == true)
    }

    /// The client-side belt: a live message of another group never enters this room.
    @Test func foreignGroupMessageIsDropped() {
        var room = ChatRoomState(groupID: "g", channelEpoch: 1)

        let inserted = room.insert(.fixture(id: "x1", groupID: "other"))
        #expect(!inserted && room.messages.isEmpty)
    }

    @Test func trimmingKeepsTheNewestAndRemembersThatOlderExist() {
        let room = ChatRoomState.fixture(messages: [first, second, third])

        let trimmed = room.trimmed(toNewest: 2)

        #expect(trimmed.messages.map(\.id) == ["m2", "m3"] && trimmed.hasOlder)
        #expect(trimmed.restWatermark == "m3")
        #expect(room.trimmed(toNewest: 3) == room)
    }

    @Test func epochIsTakenFromEveryPageAndFromNotes() {
        var room = ChatRoomState(groupID: "g", channelEpoch: 1)
        room.applyOlder(.fixture([], epoch: 2))
        #expect(room.channelEpoch == 2)
        room.noteEpoch(5)
        #expect(room.channelEpoch == 5)
    }
}
