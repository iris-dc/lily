import Foundation
import Testing
@testable import lily

/// Opening a room, history, the read marker and what arrives live.
@MainActor
struct ChatViewModelTests {
    private let group = SportGroup.fixture(id: "g", channelEpoch: 1, role: .member)
    private let first = ChatMessage.fixture(id: "m1")
    private let second = ChatMessage.fixture(id: "m2")

    /// A connected controller and a view model for `group`, with Mine holding the group.
    private func makeHarness(cached: [ChatMessage]? = nil) async -> (RealtimeHarness, ChatViewModel) {
        let harness = RealtimeHarness()
        harness.groups.result = .success([group])
        if let cached { harness.cache.store(.fixture(messages: cached), for: "g") }
        await harness.connect()
        return (harness, harness.makeChatViewModel(for: group))
    }

    @Test func appearWithoutACacheLoadsTheNewestPageAndMarksItRead() async {
        let (harness, viewModel) = await makeHarness()
        harness.chat.newestPages = [.fixture([first, second], hasMore: true)]
        harness.groups.members = [GroupMember(userId: "u-2", displayName: "Marta B.", role: .member, joinedAt: .now)]

        await viewModel.appear()

        #expect(harness.chat.newestGroupIDs == ["g"] && harness.chat.newerRequests.isEmpty)
        #expect(viewModel.room.messages.map(\.id) == ["m1", "m2"] && viewModel.hasOlder)
        #expect(viewModel.rows.count == 3, "a day divider and two bubbles")
        #expect(harness.chat.readMarks.map(\.messageID) == ["m2"])
        #expect(harness.controller.openRoom?.groupID == "g" && harness.controller.subscribedRooms["g"] == 1)
        #expect(harness.recorder.kinds == [.chatOpened] && harness.recorder.interactions.first?.groupId == "g")
        #expect(viewModel.members.map(\.displayName) == ["Marta B."])
        #expect(harness.logger.messages(in: .chat, at: .debug).contains("Read marker flushed for group g"))
    }

    /// A cached room shows at once and catches up from the REST watermark, never from the newest live message.
    @Test func appearWithACacheCatchesUpFromTheWatermark() async {
        let (harness, viewModel) = await makeHarness(cached: [first])
        harness.cache.update(groupID: "g") { $0.insert(.fixture(id: "m3")) }
        harness.chat.newerPages = [.fixture([second])]

        await viewModel.appear()

        #expect(harness.chat.newestGroupIDs.isEmpty && harness.chat.newerRequests.map(\.after) == ["m1"])
        #expect(viewModel.room.messages.map(\.id) == ["m1", "m2", "m3"] && viewModel.room.restWatermark == "m2")
    }

    @Test func appearSubscribesBeforeItCatchesUp() async {
        let (harness, viewModel) = await makeHarness(cached: [first])
        var subscribedAtCatchUp = false
        let room = RealtimeChannel.room(groupID: "g", epoch: 1)
        harness.chat.onRequest = { subscribedAtCatchUp = harness.transport.subscribedChannels.contains(room) }

        await viewModel.appear()

        #expect(subscribedAtCatchUp)
    }

    @Test func liveMessagesAppearAndTheMarkerFlushesAtMostOncePerInterval() async {
        let (harness, viewModel) = await makeHarness(cached: [first])
        await viewModel.appear()
        #expect(harness.chat.readMarks.count == 1)

        harness.transport.post(.message(second), to: .room(groupID: "g", epoch: 1))
        await settle(until: { viewModel.room.messages.count == 2 })
        await settle(until: { harness.sleep.held.contains(.seconds(AppConfig.Chat.readMarkFlushInterval)) })
        #expect(harness.chat.readMarks.count == 1, "within the interval the marker waits")

        harness.transport.post(.message(.fixture(id: "m3")), to: .room(groupID: "g", epoch: 1))
        await settle(until: { viewModel.room.messages.count == 3 })
        harness.clock.advance(by: AppConfig.Chat.readMarkFlushInterval)
        harness.sleep.release { $0 == .seconds(AppConfig.Chat.readMarkFlushInterval) }
        await settle(until: { harness.chat.readMarks.count == 2 })
        #expect(harness.chat.readMarks.last?.messageID == "m3", "one flush carries the newest id")
    }

    @Test func leavingAndBackgroundingFlushTheMarkerAtOnce() async {
        let (harness, viewModel) = await makeHarness(cached: [first])
        await viewModel.appear()
        harness.transport.post(.message(second), to: .room(groupID: "g", epoch: 1))
        await settle(until: { viewModel.room.messages.count == 2 })

        await viewModel.sceneDidEnterBackground()
        #expect(harness.chat.readMarks.map(\.messageID) == ["m1", "m2"])

        harness.transport.post(.message(.fixture(id: "m3")), to: .room(groupID: "g", epoch: 1))
        await settle(until: { viewModel.room.messages.count == 3 })
        await viewModel.cancel()
        #expect(harness.chat.readMarks.map(\.messageID) == ["m1", "m2", "m3"])
        #expect(viewModel.liveTask == nil && harness.controller.openRoom == nil)
        await settle(until: { harness.controller.consumers.isEmpty })
        await viewModel.sceneDidEnterBackground()
        #expect(harness.chat.readMarks.count == 3, "nothing new, nothing sent")
    }

    @Test func envelopesUpdateTheGroupAndNoticeWhenTheRoomIsGone() async {
        let (harness, viewModel) = await makeHarness(cached: [first])
        await viewModel.appear()
        let room = RealtimeChannel.room(groupID: "g", epoch: 1)

        harness.transport.post(.memberJoined(groupID: "g", member: .fixture(), memberCount: 6, channelEpoch: 1), to: room)
        await settle(until: { viewModel.group.memberCount == 6 })
        harness.transport.post(.groupUpdated(.fixture(id: "g", name: "Renamed", memberCount: 6)), to: room)
        await settle(until: { viewModel.group.name == "Renamed" })
        #expect(viewModel.group.role == .member, "a broadcast without a membership keeps the caller's")
        harness.transport.post(.memberLeft(groupID: "g", userID: TestFixtures.user.id, channelEpoch: 2, memberCount: 5), to: room)
        await settle(until: { viewModel.isGone })
    }

    @Test func aMemberLeftResubscribesThenCatchesUp() async {
        let (harness, viewModel) = await makeHarness(cached: [first])
        await viewModel.appear()

        harness.transport.post(.memberLeft(groupID: "g", userID: "u-9", channelEpoch: 2, memberCount: 10),
                               to: .room(groupID: "g", epoch: 1))
        await settle(until: { harness.sleep.held.contains(.seconds(0.1)) })
        #expect(harness.chat.newerRequests.count == 1, "the catch-up waits for the resubscribe")
        #expect(harness.controller.subscribedRooms["g"] == 1, "the jitter holds for the open room too")
        harness.sleep.release { $0 == .seconds(0.1) }
        await settle(until: { harness.chat.newerRequests.count == 2 })

        #expect(harness.controller.subscribedRooms["g"] == 2 && viewModel.subscribedEpoch == 2)
    }

    /// The page answers whether it brought new rows: a same-day prepend keeps the day chip as the first row, so the
    /// transcript cannot tell from the rows alone.
    @Test func loadOlderPrependsAPageWithoutMovingTheWatermark() async {
        let (harness, viewModel) = await makeHarness()
        var room = ChatRoomState(groupID: "g", channelEpoch: 1)
        room.applyNewest(.fixture([second], hasMore: true))
        harness.cache.store(room, for: "g")
        harness.chat.olderPages = [.fixture([first])]
        let firstRow = viewModel.rows.first?.id

        let loaded = await viewModel.loadOlder()

        #expect(loaded && viewModel.rows.first?.id == firstRow, "same day: the first row is still the day chip")
        #expect(harness.chat.olderRequests.map(\.before) == ["m2"])
        #expect(viewModel.room.messages.map(\.id) == ["m1", "m2"] && !viewModel.hasOlder && viewModel.room.restWatermark == "m2")
        #expect(await !viewModel.loadOlder())
        #expect(harness.chat.olderRequests.count == 1, "nothing older to ask for")
    }

    @Test func anOlderPageThatBringsNothingNewSaysSo() async {
        let (harness, viewModel) = await makeHarness()
        var room = ChatRoomState(groupID: "g", channelEpoch: 1)
        room.applyNewest(.fixture([second], hasMore: true))
        harness.cache.store(room, for: "g")
        harness.chat.olderPages = [.fixture([second], hasMore: true)]

        #expect(await !viewModel.loadOlder(), "every row of the page was already held")

        harness.chat.pageError = AppError.chatUnavailable
        #expect(await !viewModel.loadOlder())
        #expect(harness.errorCenter.current?.error == .chatUnavailable)
    }

    /// The backend's cursor may point past hidden messages; when the page named one, that is what the app asks with.
    @Test func loadOlderAsksBeforeTheCursorThePageNamed() async {
        let (harness, viewModel) = await makeHarness()
        var room = ChatRoomState(groupID: "g", channelEpoch: 1)
        room.applyNewest(.fixture([second], hasMore: true, nextBefore: "c-1"))
        harness.cache.store(room, for: "g")
        harness.chat.olderPages = [.fixture([first], hasMore: true)]

        await viewModel.loadOlder()
        await viewModel.loadOlder()

        #expect(harness.chat.olderRequests.map(\.before) == ["c-1", "m1"], "then before the oldest id, the page named none")
    }

    @Test func losingAccessDropsTheRoom() async {
        let (harness, viewModel) = await makeHarness(cached: [first])
        harness.chat.pageError = AppError.notAMember

        await viewModel.appear()

        #expect(viewModel.isGone && harness.cache.room(for: "g") == nil)
        #expect(harness.errorCenter.current?.error == .notAMember)
    }

    @Test func deletingAMessageLeavesATombstone() async {
        let (harness, viewModel) = await makeHarness(cached: [first, second])

        await viewModel.delete(first)

        #expect(harness.chat.deletedMessageIDs == ["m1"])
        #expect(viewModel.room.messages.map(\.isDeleted) == [true, false])
        #expect(harness.logger.messages(in: .chat, at: .info).contains("Message m1 deleted in group g"))
    }

    /// The backend gates deletes behind the current terms like every other write: the terms sheet must follow the popup.
    @Test func aTermsRequiredOnDeleteRaisesTheTermsSheet() async {
        let (harness, viewModel) = await makeHarness(cached: [first])
        harness.chat.deleteError = AppError.termsRequired

        await viewModel.delete(first)

        #expect(harness.errorCenter.current?.error == .termsRequired && harness.termsRequiredCount == 1)
        #expect(viewModel.room.messages.map(\.isDeleted) == [false])
    }
}
