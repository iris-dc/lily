import Foundation
import Testing
@testable import lily

/// Clearing a room for the caller: a group keeps its row and gets an empty room back, a conversation leaves Mine, and a
/// refused clear changes nothing.
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

        #expect(await harness.clearer.clear(group))

        #expect(harness.chat.clearedGroupIDs == ["g"])
        let room = try #require(harness.cache.room(for: "g"))
        #expect(room.messages.isEmpty && room.hasHistory && !room.hasOlder && room.channelEpoch == 2)
        #expect(!harness.unread.hasUnread(groupID: "g"))
        #expect(harness.store.groups.map(\.id) == ["g"])
        #expect(harness.chatLogs(.info).contains("Chat history cleared for group g (hidden: false)"))
        #expect(harness.logger.messages(in: .cache, at: .info).contains("Room cache dropped for group g (history cleared)"))
    }

    @Test func deletingAConversationDropsItsRoomAndTakesItOutOfMine() async {
        await seed(conversation)
        harness.chat.clearAnswersHidden = true
        let changesBefore = harness.changes.version

        #expect(await harness.clearer.clear(conversation))

        #expect(harness.store.groups.isEmpty)
        #expect(harness.cache.room(for: conversation.id) == nil)
        #expect(!harness.unread.hasUnread(groupID: conversation.id))
        #expect(harness.changes.version > changesBefore, "sibling screens learn that Mine changed")
        #expect(harness.chatLogs(.info).contains("Chat history cleared for group \(conversation.id) (hidden: true)"))
    }

    @Test func aRefusedClearChangesNothingAndReachesThePopup() async {
        await seed(group)
        harness.chat.clearError = AppError.chatUnavailable

        #expect(await !harness.clearer.clear(group))

        #expect(harness.cache.room(for: "g")?.messages.count == 2)
        #expect(harness.unread.hasUnread(groupID: "g") && harness.store.groups.map(\.id) == ["g"])
        #expect(harness.errorCenter.current?.error == .chatUnavailable)
        #expect(harness.chatLogs(.error).contains("Clearing the chat failed for group g: chatUnavailable"))

        harness.chat.clearError = AppError.termsRequired
        #expect(await !harness.clearer.clear(group))
        #expect(harness.termsRequiredCount == 1, "a terms gate raises the terms sheet as on the groups screens")
    }

    @Test func cancellationStaysQuiet() async {
        await seed(group)
        harness.chat.clearError = CancellationError()

        #expect(await !harness.clearer.clear(group))

        #expect(harness.errorCenter.current == nil && harness.chatLogs(.error).isEmpty)
        #expect(harness.cache.room(for: "g")?.messages.count == 2)
    }
}
