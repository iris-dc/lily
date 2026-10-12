import Foundation
import Testing
@testable import lily

/// Clearing from the open chat: the room empties for the caller and the screen stays for a group, leaves for a
/// conversation; a refused clear keeps everything.
@MainActor
struct ChatViewModelClearTests {
    private let group = SportGroup.fixture(id: "g", channelEpoch: 1, role: .member)
    private let conversation = SportGroup.conversationFixture()

    /// A connected controller, Mine holding `group`, its room cached with one line, the chat open and one bubble unsent.
    private func makeOpenChat(for group: SportGroup) async -> (RealtimeHarness, ChatViewModel) {
        let harness = RealtimeHarness()
        harness.groups.result = .success([group])
        await harness.store.reload()
        harness.cache.store(.fixture(groupID: group.id, messages: [.fixture(id: "m1", groupID: group.id)]), for: group.id)
        await harness.connect()
        let viewModel = harness.makeChatViewModel(for: group)
        await viewModel.appear()
        viewModel.pending.append(PendingMessage(draft: MessageDraft(), sentAt: harness.clock.now))
        return (harness, viewModel)
    }

    @Test func clearingAGroupEmptiesTheRoomAndKeepsTheScreen() async {
        let (harness, viewModel) = await makeOpenChat(for: group)
        #expect(viewModel.lastFlushedReadID == "m1" && viewModel.rows.count == 3)

        await viewModel.clearHistory()

        #expect(harness.chat.clearedGroupIDs == ["g"])
        #expect(viewModel.pending.isEmpty && viewModel.rows.isEmpty && viewModel.room.hasHistory)
        #expect(viewModel.lastFlushedReadID == nil && viewModel.lastFlushAt == nil, "the marker starts over")
        #expect(!viewModel.isGone)

        harness.transport.post(.message(.fixture(id: "m2")), to: .room(groupID: "g", epoch: 1))
        await settle(until: { viewModel.room.messages.map(\.id) == ["m2"] })
        #expect(viewModel.rows.count == 2, "a line written after the clear lands in the emptied room")
    }

    /// A picture that never left goes with the room it was meant for: nothing of the unsent bubble stays in tmp.
    @Test func clearingTakesTheUnsentBubblesFilesWithIt() async throws {
        let (harness, viewModel) = await makeOpenChat(for: group)
        viewModel.draft.text = "hello"
        viewModel.attachments.add(imageData: Data(repeating: 1, count: 300))
        await settle(until: { viewModel.canSend })
        let files = try #require(viewModel.attachments.drafts.first).localFiles
        harness.chat.sendErrors = [AppError.contentRejected]
        await viewModel.send()
        #expect(viewModel.pending.count == 2 && files.allSatisfy { FileManager.default.fileExists(atPath: $0.path()) })

        await viewModel.clearHistory()

        #expect(viewModel.pending.isEmpty)
        #expect(files.allSatisfy { !FileManager.default.fileExists(atPath: $0.path()) }, "the files went with the bubble")
    }

    @Test func deletingAConversationLeavesTheScreen() async {
        let (harness, viewModel) = await makeOpenChat(for: conversation)
        harness.chat.clearAnswersHidden = true

        await viewModel.clearHistory()

        #expect(viewModel.isGone && viewModel.pending.isEmpty)
        #expect(harness.store.groups.isEmpty && harness.cache.room(for: conversation.id) == nil)
    }

    @Test func aRefusedClearKeepsTheRoomAndTheUnsentBubble() async {
        let (harness, viewModel) = await makeOpenChat(for: group)
        harness.chat.clearError = AppError.chatUnavailable

        await viewModel.clearHistory()

        #expect(viewModel.pending.count == 1 && viewModel.room.messages.map(\.id) == ["m1"])
        #expect(viewModel.lastFlushedReadID == "m1" && !viewModel.isGone)
        #expect(harness.errorCenter.current?.error == .chatUnavailable)
    }
}
