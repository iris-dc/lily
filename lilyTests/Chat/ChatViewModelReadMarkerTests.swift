import Foundation
import Testing
@testable import lily

/// The read marker after a refused flush, and the unread mark the open room moves before any flush reaches the backend.
@MainActor
struct ChatViewModelReadMarkerTests {
    private let group = SportGroup.fixture(id: "g", channelEpoch: 1, role: .member)
    private let first = ChatMessage.fixture(id: "m1")
    private let second = ChatMessage.fixture(id: "m2")
    private let interval = Duration.seconds(AppConfig.Chat.readMarkFlushInterval)

    /// A connected controller and a view model for `group`, with Mine holding the group.
    private func makeHarness(cached: [ChatMessage]? = nil) async -> (RealtimeHarness, ChatViewModel) {
        let harness = RealtimeHarness()
        harness.groups.result = .success([group])
        if let cached { harness.cache.store(.fixture(messages: cached), for: "g") }
        await harness.connect()
        return (harness, harness.makeChatViewModel(for: group))
    }

    /// The room opened with its first flush refused, then a live line whose marker is waiting out the interval.
    private func makeRoomWaitingAfterARefusedFlush() async -> (RealtimeHarness, ChatViewModel) {
        let (harness, viewModel) = await makeHarness(cached: [first])
        harness.chat.readMarkerError = AppError.network
        await viewModel.appear()
        harness.chat.readMarkerError = nil
        harness.transport.post(.message(second), to: .room(groupID: "g", epoch: 1))
        await settle(until: { viewModel.room.messages.count == 2 })
        await settle(until: { harness.sleep.held.contains(interval) })
        return (harness, viewModel)
    }

    /// A refused marker is bookkeeping: a warning, no popup, and the next attempt keeps the interval's pace instead
    /// of asking again at once.
    @Test func aFailedReadMarkerFlushWaitsTheIntervalAndStaysQuiet() async {
        let (harness, viewModel) = await makeHarness(cached: [first])
        harness.chat.readMarkerError = AppError.network

        await viewModel.appear()

        #expect(harness.chat.readMarks.map(\.messageID) == ["m1"])
        #expect(harness.errorCenter.current == nil)
        #expect(harness.chatLogs(.warning).contains("Read marker failed for group g: network"))

        harness.chat.readMarkerError = nil
        harness.transport.post(.message(second), to: .room(groupID: "g", epoch: 1))
        await settle(until: { viewModel.room.messages.count == 2 })
        await settle(until: { harness.sleep.held.contains(interval) })
        #expect(harness.chat.readMarks.count == 1, "the refused flush is not repeated at once")
        #expect(harness.sleep.held.filter { $0 == interval }.count == 1, "one attempt waits the interval")

        harness.clock.advance(by: AppConfig.Chat.readMarkFlushInterval)
        harness.sleep.release { $0 == interval }
        await settle(until: { harness.chat.readMarks.map(\.messageID) == ["m1", "m2"] })
    }

    @Test func backgroundingDuringTheWaitAfterAFailureFlushesAtOnce() async {
        let (harness, viewModel) = await makeRoomWaitingAfterARefusedFlush()
        #expect(harness.chat.readMarks.count == 1)

        await viewModel.sceneDidEnterBackground()

        #expect(harness.chat.readMarks.map(\.messageID) == ["m1", "m2"])
        harness.sleep.release { $0 == interval }
        await harness.yield()
        #expect(harness.chat.readMarks.count == 2, "the waiting attempt went with the flush and sends nothing more")
    }

    /// What the open room shows counts as read before the backend hears of it: a Mine snapshot that still reports the
    /// line just read as unread is overruled, while a line newer than anything read here still counts.
    @Test func aLiveMessageReadInTheOpenRoomAdvancesTheUnreadMark() async {
        let (harness, viewModel) = await makeHarness(cached: [first])
        await viewModel.appear()
        harness.transport.post(.message(second), to: .room(groupID: "g", epoch: 1))
        await settle(until: { viewModel.room.messages.count == 2 })
        await settle(until: { harness.sleep.held.contains(interval) })
        #expect(harness.chat.readMarks.map(\.messageID) == ["m1"], "the marker for m2 is still waiting")

        harness.unread.apply(groups: [.fixture(id: "g", lastMessageId: "m2", role: .member, hasUnread: true)])
        #expect(!harness.unread.hasUnread(groupID: "g"))

        harness.unread.apply(groups: [.fixture(id: "g", lastMessageId: "m3", role: .member, hasUnread: true)])
        #expect(harness.unread.hasUnread(groupID: "g"))
    }
}
