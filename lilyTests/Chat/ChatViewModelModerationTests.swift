import Foundation
import Testing
@testable import lily

/// Blocking from a bubble's menu: the sender's lines leave the transcript at once because the block list feeds `rows`,
/// their live lines stay hidden, a list the shell's sync loaded hides them without a block here, and a refused block
/// keeps every row.
@MainActor
struct ChatViewModelModerationTests {
    private let group = SportGroup.fixture(id: "g", channelEpoch: 1, role: .member)
    /// Marta's two lines around Jonas's.
    private let m1 = ChatMessage.fixture(id: "m1", senderUserID: "u-2")
    private let m2 = ChatMessage.fixture(id: "m2", senderUserID: "u-3", senderName: "Jonas")
    private let m3 = ChatMessage.fixture(id: "m3", senderUserID: "u-2")

    /// A connected controller, Mine holding the group, its room cached with the three lines, the chat open; `prepare`
    /// runs before the chat opens, for what the shell would have done first.
    private func makeOpenChat(prepare: (RealtimeHarness) async -> Void = { _ in }) async -> (RealtimeHarness, ChatViewModel) {
        let harness = RealtimeHarness()
        harness.groups.result = .success([group])
        await harness.store.reload()
        harness.cache.store(.fixture(groupID: group.id, messages: [m1, m2, m3]), for: group.id)
        await harness.connect()
        await prepare(harness)
        let viewModel = harness.makeChatViewModel(for: group)
        await viewModel.appear()
        return (harness, viewModel)
    }

    /// The ids of the message rows, in transcript order; the day chip is left out.
    private func messageIDs(in rows: [ChatRow]) -> [String] {
        rows.compactMap { if case .message(let row) = $0 { row.message.id } else { nil } }
    }

    @Test func blockingHidesTheSendersRows() async {
        let (harness, viewModel) = await makeOpenChat()
        #expect(viewModel.rows.count == 4 && messageIDs(in: viewModel.rows) == ["m1", "m2", "m3"])

        await viewModel.block(senderOf: m1)

        #expect(harness.moderation.blockedUserIDs == ["u-2"])
        #expect(harness.blocks.blockedUserIDs == ["u-2"])
        #expect(viewModel.rows.count == 2 && messageIDs(in: viewModel.rows) == ["m2"], "the day chip and Jonas's line stay")
        #expect(harness.errorCenter.current == nil)
        #expect(harness.chatLogs(.info).contains("Blocked user u-2 from group g"))
    }

    @Test func aBlockedSendersLiveLinesStayHidden() async {
        let (harness, viewModel) = await makeOpenChat()
        await viewModel.block(senderOf: m1)

        harness.transport.post(.message(.fixture(id: "m4", senderUserID: "u-2")), to: .room(groupID: "g", epoch: 1))
        await settle(until: { viewModel.room.messages.map(\.id).contains("m4") })

        #expect(messageIDs(in: viewModel.rows) == ["m2"], "the live line landed in the room and stays hidden")
    }

    /// The shell loads the list once per user; a room opened afterwards hides the blocked sender without a block of its own.
    @Test func theListLoadedBySyncHidesRowsWithoutABlockHere() async {
        let (harness, viewModel) = await makeOpenChat { harness in
            harness.moderation.blocked = ["u-2"]
            await harness.blocks.loadIfNeeded()
        }

        #expect(messageIDs(in: viewModel.rows) == ["m2"])
        #expect(harness.moderation.blockedUserIDs.isEmpty, "no block was sent from this room")
    }

    @Test func aRefusedBlockKeepsTheRowsAndReachesThePopup() async {
        let (harness, viewModel) = await makeOpenChat()
        harness.moderation.error = AppError.blockLimitReached

        await viewModel.block(senderOf: m1)

        #expect(messageIDs(in: viewModel.rows) == ["m1", "m2", "m3"])
        #expect(harness.blocks.blockedUserIDs.isEmpty)
        #expect(harness.errorCenter.current?.error == .blockLimitReached)
        #expect(harness.chatLogs(.error) == ["Block failed in group g: blockLimitReached"])
    }

    @Test func aCancelledBlockStaysQuiet() async {
        let (harness, viewModel) = await makeOpenChat()
        harness.moderation.error = CancellationError()

        await viewModel.block(senderOf: m1)

        #expect(harness.errorCenter.current == nil)
        #expect(harness.chatLogs(.error).isEmpty)
        #expect(messageIDs(in: viewModel.rows) == ["m1", "m2", "m3"])
    }

    @Test func aMessagesReportTargetNamesTheMessageAndTheRoom() {
        let viewModel = RealtimeHarness().makeChatViewModel(for: group)

        let target = viewModel.reportTarget(for: m1)

        #expect(target == .message(id: "m1", groupID: "g"))
        #expect(target.kind == .message && target.groupID == "g")
    }
}
