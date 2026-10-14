import Foundation
import Testing
@testable import lily

/// Clearing a room for the caller: a group keeps its row and gets its room back seated at the floor, a conversation
/// leaves Mine, and a refused clear changes nothing.
@MainActor
struct ChatHistoryClearerTests {
    private let harness = RealtimeHarness()
    private let group = SportGroup.fixture(id: "g", role: .member)
    private let conversation = SportGroup.conversationFixture()

    /// Mine holds `group`, its room holds two messages with older ones behind, and the newest is unread.
    private func seed(_ group: SportGroup) async {
        harness.groups.result = .success([group])
        await harness.store.reload()
        var room = ChatRoomState(groupID: group.id, channelEpoch: 1)
        room.applyNewest(.fixture([.fixture(id: "m1", groupID: group.id), .fixture(id: "m2", groupID: group.id)], hasMore: true))
        harness.cache.store(room, for: group.id)
        harness.unread.markUnread(groupID: group.id, messageID: "m2")
    }

    @Test func clearingAGroupLeavesAnEmptyRoomAndKeepsItInMine() async throws {
        await seed(group)
        harness.chat.responseEpoch = 2

        let answer = await harness.clearer.clear(group)

        let cleared = try #require(answer)
        #expect(!cleared.hidden && harness.chat.clearedGroupIDs == ["g"])
        let room = try #require(harness.cache.room(for: "g"))
        #expect(room.messages.isEmpty && room.hasHistory && !room.hasOlder && room.channelEpoch == 2)
        #expect(room.restWatermark == cleared.historyFloor, "the next catch-up asks from the floor")
        #expect(!harness.unread.hasUnread(groupID: "g"))
        #expect(harness.store.groups.map(\.id) == ["g"])
        #expect(harness.chatLogs(.info).contains("Chat history cleared for group g (hidden: false)"))
        let cacheLines = harness.logger.messages(in: .cache, at: .info)
        #expect(!cacheLines.contains("Room cache dropped for group g (history cleared)"), "seated at the floor, never dropped")
    }

    /// After a clear the watermark sits at the floor, so a group whose newest line is below it has nothing to catch up.
    @Test func aClearedRoomKeepsItsWatermark() async {
        harness.groups.result = .success([group])
        await harness.store.reload()
        harness.cache.store(.fixture(groupID: "g", messages: [.fixture(id: "m1", groupID: "g")]), for: "g")
        let moved = SportGroup.fixture(id: "g", lastMessageId: "m2", role: .member)
        await harness.catchUp.catchUpMovedRooms([moved], openRoomID: nil, maxConcurrent: 1)
        #expect(harness.chat.newerRequests.map(\.after) == ["m1"], "behind its group's newest, the room is caught up")

        _ = await harness.clearer.clear(group)
        await harness.catchUp.catchUpMovedRooms([moved], openRoomID: nil, maxConcurrent: 1)

        #expect(harness.chat.newerRequests.count == 1, "the floor is past m2: nothing to fetch")
        #expect(harness.logger.messages(in: .cache, at: .debug).contains("Catch-up skipped for group g (nothing new)"))
    }

    /// A line another member wrote while the DELETE was out is above the floor: the server kept it, and so does the
    /// room, with the watermark at the floor.
    @Test func aLiveLineDuringTheClearSurvivesAboveTheFloor() async throws {
        await seed(group)
        harness.chat.clearFloor = "m2"
        harness.chat.holdsRequests = true
        let clear = Task { await harness.clearer.clear(group) }
        await settle(until: { harness.chat.clearedGroupIDs == ["g"] })
        harness.cache.update(groupID: "g") { $0.insert(.fixture(id: "m3", groupID: "g")) }

        harness.chat.releaseRequests()
        _ = await clear.value

        let room = try #require(harness.cache.room(for: "g"))
        #expect(room.messages.map(\.id) == ["m3"] && room.restWatermark == "m2")
    }

    /// A clear from a Chats row of a room never opened ends the same way as one of an open room: seated at the floor, so
    /// the first open catches up from there.
    @Test func clearingARoomNeverOpenedStoresAClearedOne() async throws {
        harness.groups.result = .success([group])
        await harness.store.reload()
        #expect(harness.cache.room(for: "g") == nil)

        let answer = await harness.clearer.clear(group)

        let cleared = try #require(answer)
        let room = try #require(harness.cache.room(for: "g"))
        #expect(room.hasHistory && room.messages.isEmpty && !room.hasOlder)
        #expect(room.restWatermark == cleared.historyFloor && room.channelEpoch == cleared.channelEpoch)
    }

    @Test func deletingAConversationDropsItsRoomAndTakesItOutOfMine() async {
        await seed(conversation)
        harness.chat.clearAnswersHidden = true
        let changesBefore = harness.changes.version

        let cleared = await harness.clearer.clear(conversation)

        #expect(cleared?.hidden == true)
        #expect(harness.store.groups.isEmpty)
        #expect(harness.cache.room(for: conversation.id) == nil)
        #expect(!harness.unread.hasUnread(groupID: conversation.id))
        #expect(harness.changes.version > changesBefore, "sibling screens learn that Mine changed")
        #expect(harness.chatLogs(.info).contains("Chat history cleared for group \(conversation.id) (hidden: true)"))
    }

    @Test func aRefusedClearChangesNothingAndReachesThePopup() async {
        await seed(group)
        harness.chat.clearError = AppError.chatUnavailable

        #expect(await harness.clearer.clear(group) == nil)

        #expect(harness.cache.room(for: "g")?.messages.count == 2)
        #expect(harness.unread.hasUnread(groupID: "g") && harness.store.groups.map(\.id) == ["g"])
        #expect(harness.errorCenter.current?.error == .chatUnavailable)
        #expect(harness.chatLogs(.error).contains("Clearing the chat failed for group g: chatUnavailable"))

        harness.chat.clearError = AppError.termsRequired
        #expect(await harness.clearer.clear(group) == nil)
        #expect(harness.termsRequiredCount == 1, "a terms gate raises the terms sheet as on the groups screens")
    }

    /// The terms gate is a refusal the room expects: a warning, never an error, and the terms sheet as on the groups screens.
    @Test func aRefusedClearIsAWarningNotAnError() async {
        await seed(group)
        harness.chat.clearError = AppError.termsRequired

        #expect(await harness.clearer.clear(group) == nil)

        #expect(harness.chatLogs(.warning).filter { $0 == "Clearing the chat failed for group g: termsRequired" }.count == 1)
        #expect(harness.chatLogs(.error).isEmpty)
        #expect(harness.termsRequiredCount == 1)
    }

    @Test func cancellationStaysQuiet() async {
        await seed(group)
        harness.chat.clearError = CancellationError()

        #expect(await harness.clearer.clear(group) == nil)

        #expect(harness.errorCenter.current == nil && harness.chatLogs(.error).isEmpty)
        #expect(harness.cache.room(for: "g")?.messages.count == 2)
    }

    /// A `hidden` verdict takes the room off the realtime side too: subscription, open room and known epoch go through the
    /// controller's one departure while the connection stays up.
    @Test func deletingAConversationUnsubscribesItsRoomAtOnce() async {
        await seed(conversation)
        await harness.connect()
        harness.controller.setOpenRoom(RoomSubscription(groupID: conversation.id, epoch: conversation.channelEpoch))
        harness.chat.clearAnswersHidden = true
        #expect(harness.controller.subscribedRooms[conversation.id] == conversation.channelEpoch)

        _ = await harness.clearer.clear(conversation)

        #expect(harness.controller.subscribedRooms[conversation.id] == nil && harness.controller.openRoom == nil)
        #expect(harness.controller.knownEpochs[conversation.id] == nil)
        #expect(harness.chatLogs(.info).contains("Group \(conversation.id) dropped (history cleared)"))
        #expect(harness.controller.state == .connected)
    }

    /// A group the backend still lists keeps its room subscribed and open: only the history moved.
    @Test func clearingAGroupKeepsItsRoomSubscribed() async {
        await seed(group)
        await harness.connect()
        harness.controller.setOpenRoom(RoomSubscription(groupID: "g", epoch: 1))
        #expect(harness.controller.subscribedRooms["g"] == 1)

        _ = await harness.clearer.clear(group)

        #expect(harness.controller.subscribedRooms["g"] == 1 && harness.controller.openRoom?.groupID == "g")
        #expect(!harness.chatLogs(.info).contains { $0.contains("dropped") })
    }
}
