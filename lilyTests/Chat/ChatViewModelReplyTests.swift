import Foundation
import Testing
@testable import lily

/// Replying from the open chat: the quote on the draft, the send that carries it, the bubble that shows it, the refusal
/// when the original is gone, and the lookup that scrolls to a quoted original.
@MainActor
struct ChatViewModelReplyTests {
    private let group = SportGroup.fixture(id: "g", channelEpoch: 1, role: .member)
    private let martas = ChatMessage.fixture(id: "m1", text: "Anyone up for a game this week?")

    /// A connected controller, the room cached with `messages` (Marta's line alone by default) and the chat open.
    private func makeOpenChat(room: ChatRoomState? = nil) async -> (RealtimeHarness, ChatViewModel) {
        let harness = RealtimeHarness()
        harness.groups.result = .success([group])
        harness.cache.store(room ?? .fixture(messages: [martas]), for: "g")
        await harness.connect()
        let viewModel = harness.makeChatViewModel(for: group)
        await viewModel.appear()
        return (harness, viewModel)
    }

    private func row(of message: ChatMessage, in viewModel: ChatViewModel) throws -> MessageRow {
        try #require(viewModel.rows.lazy.compactMap { row -> MessageRow? in
            if case .message(let messageRow) = row, messageRow.message.id == message.id { return messageRow }
            return nil
        }.first)
    }

    @Test func startReplyQuotesTheRowAndCancelDropsIt() async throws {
        let (_, viewModel) = await makeOpenChat()
        let row = try row(of: martas, in: viewModel)

        viewModel.startReply(to: row)

        #expect(viewModel.replyTarget == ReplyQuote.fixture(excerpt: "Anyone up for a game this week?"))
        #expect(viewModel.draft.payload.replyToMessageId == "m1")

        viewModel.cancelReply()
        #expect(viewModel.replyTarget == nil && viewModel.draft.payload.replyToMessageId == nil)
    }

    /// The menu offers Reply on any member's message that is not deleted; a tombstone or a system row has nothing to quote.
    @Test func deletedAndSystemRowsCannotBeAnswered() async throws {
        let deleted = ChatMessage.fixture(id: "m2", isDeleted: true)
        let system = ChatMessage.fixture(id: "m3", kind: .eventCreated, eventID: "e1")
        let (_, viewModel) = await makeOpenChat(room: .fixture(messages: [martas, deleted, system]))

        #expect(viewModel.canReply(to: martas) && !viewModel.canReply(to: deleted) && !viewModel.canReply(to: system))
        viewModel.startReply(to: try row(of: deleted, in: viewModel))
        #expect(viewModel.replyTarget == nil)
    }

    /// The pending bubble carries the quote while the send is in flight, the fresh draft is plain again, and the send
    /// names the target; the stored message comes back with the quote and replaces the bubble.
    @Test func sendCarriesTheTargetAndThePendingBubbleTheQuote() async throws {
        let (harness, viewModel) = await makeOpenChat()
        viewModel.startReply(to: try row(of: martas, in: viewModel))
        viewModel.draft.text = "Thursday works"
        harness.chat.holdsRequests = true

        let send = Task { await viewModel.send() }
        await settle(until: { viewModel.pending.count == 1 && harness.chat.sentDrafts.count == 1 })
        #expect(viewModel.pending[0].replyTo?.messageId == "m1" && viewModel.replyTarget == nil)
        #expect(harness.chat.sentDrafts[0].payload.replyToMessageId == "m1")
        harness.chat.releaseRequests()
        await send.value

        #expect(viewModel.pending.isEmpty && viewModel.room.messages.last?.replyTo?.messageId == "m1")
        #expect(viewModel.room.messages.last?.text == "Thursday works")
    }

    /// `REPLY_TARGET_NOT_FOUND`: the bubble fails, loses its quote and tells the caller; Retry sends the plain message.
    @Test func aGoneTargetFailsTheBubbleAndRetrySendsItPlain() async throws {
        let (harness, viewModel) = await makeOpenChat()
        viewModel.startReply(to: try row(of: martas, in: viewModel))
        viewModel.draft.text = "Thursday works"
        harness.chat.sendErrors = [AppError.replyTargetNotFound]

        await viewModel.send()

        #expect(viewModel.pending.map(\.hasFailed) == [true] && viewModel.pending[0].replyTo == nil)
        #expect(harness.errorCenter.current?.error == .replyTargetNotFound)
        #expect(harness.chat.sentDrafts.map { $0.payload.replyToMessageId } == ["m1"])

        await viewModel.retry(viewModel.pending[0])

        #expect(harness.chat.sentDrafts.map { $0.payload.replyToMessageId } == ["m1", nil])
        let clientIDs = harness.chat.sentDrafts.map(\.clientMessageID)
        #expect(clientIDs.count == 2 && Set(clientIDs).count == 1, "the retry keeps the id")
        #expect(viewModel.pending.isEmpty && viewModel.room.messages.last?.text == "Thursday works")
        #expect(viewModel.room.messages.last?.replyTo == nil)
    }

    /// A quoted original before the history held is reached by loading older pages, as many as it takes within the cap.
    @Test func revealQuotedLoadsOlderPagesUntilTheOriginalIsHeld() async {
        var room = ChatRoomState(groupID: "g", channelEpoch: 1)
        room.applyNewest(.fixture([.fixture(id: "m5")], hasMore: true))
        let (harness, viewModel) = await makeOpenChat(room: room)
        harness.chat.olderPages = [.fixture([.fixture(id: "m4")], hasMore: true), .fixture([.fixture(id: "m3")], hasMore: true)]

        #expect(await viewModel.revealQuoted(id: "m3"))

        #expect(harness.chat.olderRequests.map(\.before) == ["m5", "m4"])
        #expect(viewModel.room.messages.map(\.id) == ["m3", "m4", "m5"] && viewModel.hasOlder)
    }

    @Test func revealQuotedStopsAfterThePageCap() async {
        var room = ChatRoomState(groupID: "g", channelEpoch: 1)
        room.applyNewest(.fixture([.fixture(id: "m9")], hasMore: true))
        let (harness, viewModel) = await makeOpenChat(room: room)
        harness.chat.olderPages = ["m8", "m7", "m6", "m5"].map { .fixture([.fixture(id: $0)], hasMore: true) }

        #expect(await !viewModel.revealQuoted(id: "m1"))

        #expect(harness.chat.olderRequests.count == AppConfig.Chat.maxReplyLookupPages)
        #expect(viewModel.room.messages.map(\.id) == ["m6", "m7", "m8", "m9"])
        #expect(harness.logger.messages(in: .chat, at: .debug).contains("Quoted message m1 not within 3 older pages of group g"))
    }

    /// Held already: nothing to load. Before the history with no page before (or one that fails): not reachable.
    @Test func revealQuotedAnswersWithoutARequestWhenHeldOrUnreachable() async {
        let (harness, viewModel) = await makeOpenChat(room: .fixture(messages: [martas]))

        #expect(await viewModel.revealQuoted(id: "m1"))
        #expect(await !viewModel.revealQuoted(id: "m0"), "no older page exists")
        #expect(harness.chat.olderRequests.isEmpty)

        var room = ChatRoomState(groupID: "g", channelEpoch: 1)
        room.applyNewest(.fixture([martas], hasMore: true))
        harness.cache.store(room, for: "g")
        harness.chat.pageError = AppError.chatUnavailable
        #expect(await !viewModel.revealQuoted(id: "m0"))
        #expect(harness.chat.olderRequests.count == 1 && harness.errorCenter.current?.error == .chatUnavailable)
    }

    /// The backend never rewrites a stored quote; the room's tombstones say whether the original is gone, whether the
    /// delete arrived live or the message was loaded as a tombstone.
    @Test func quoteIsDeletedFollowsTheRoomsTombstones() async {
        let tombstone = ChatMessage.fixture(id: "m2", isDeleted: true)
        let (_, viewModel) = await makeOpenChat(room: .fixture(messages: [martas, tombstone]))
        let quote = ReplyQuote.fixture()

        #expect(!viewModel.quoteIsDeleted(quote) && viewModel.quoteIsDeleted(.fixture(messageId: "m2")))
        #expect(!viewModel.quoteIsDeleted(.fixture(messageId: "unknown")))

        viewModel.mutateRoom { $0.markDeleted(id: "m1") }
        #expect(viewModel.quoteIsDeleted(quote))
    }
}
