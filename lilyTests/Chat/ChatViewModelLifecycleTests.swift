import Foundation
import Testing
@testable import lily

/// The lifecycle of one open room: what `appear()` subscribes at and where it stops, a second appear after a pop, a group
/// deleted under the open room, and what a failed first page leaves on the screen.
@MainActor
struct ChatViewModelLifecycleTests {
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

    /// A live event moved the cache's epoch while Mine's row, which seeded the view model, still says 1: the screen
    /// subscribes at the cache's epoch, and the catch-up's answer at that epoch is no epoch change.
    @Test func appearSubscribesAtTheCachesEpoch() async {
        let (harness, viewModel) = await makeHarness(cached: [first])
        harness.transport.post(.memberJoined(groupID: "g", member: .fixture(), memberCount: 6, channelEpoch: 2),
                               to: .room(groupID: "g", epoch: 1))
        await settle(until: { harness.controller.subscribedRooms["g"] == 2 })
        harness.chat.epoch = 2

        await viewModel.appear()

        #expect(harness.chat.newerRequests.count == 1, "one catch-up, not another for an epoch already subscribed")
        #expect(viewModel.subscribedEpoch == 2 && harness.controller.subscribedRooms["g"] == 2)
        let epochLines = harness.chatLogs(.info).filter { $0.hasPrefix("Epoch changed for group g") }
        #expect(epochLines.count == 1, "the controller's line on the event; the view model adds none")
    }

    @Test func aCachedRoomIsACacheHitOnAppear() async {
        let (harness, viewModel) = await makeHarness(cached: [first])

        await viewModel.appear()

        let hit = "Room cache hit for group g; catching up from the watermark"
        #expect(harness.logger.messages(in: .cache, at: .debug).filter { $0 == hit }.count == 1)
        #expect(!harness.logger.messages(in: .cache).contains { $0.hasPrefix("Room cache miss") })
    }

    @Test func anUncachedRoomIsACacheMissOnAppear() async {
        let (harness, viewModel) = await makeHarness()
        harness.chat.newestPages = [.fixture([first])]

        await viewModel.appear()

        let miss = "Room cache miss for group g; loading the newest page"
        #expect(harness.logger.messages(in: .cache, at: .debug).filter { $0 == miss }.count == 1)
        #expect(!harness.logger.messages(in: .cache).contains { $0.hasPrefix("Room cache hit") })
    }

    @Test func aRoomMarkedGoneByTheFirstPageStartsNoLiveTask() async {
        let (harness, viewModel) = await makeHarness(cached: [first])
        harness.chat.pageError = AppError.notAMember
        harness.groups.members = [.fixture()]

        await viewModel.appear()

        #expect(viewModel.isGone && harness.cache.room(for: "g") == nil)
        #expect(harness.errorCenter.current?.error == .notAMember)
        #expect(viewModel.liveTask == nil && harness.controller.consumers.isEmpty)
        #expect(harness.controller.openRoom == nil, "a dropped room is not the controller's open one")
        #expect(harness.chat.readMarks.isEmpty)
        #expect(viewModel.members.isEmpty, "the seeded roster would have answered: no request went out")
    }

    /// The screen left while the first page was in flight: the page still lands in the cache, nothing else starts.
    @Test func aCancelledAppearStartsNothing() async {
        let (harness, viewModel) = await makeHarness()
        harness.chat.newestPages = [.fixture([first])]
        harness.groups.members = [.fixture()]
        harness.chat.holdsRequests = true
        let run = Task { await viewModel.appear() }
        await settle(until: { harness.chat.newestGroupIDs == ["g"] })

        run.cancel()
        harness.chat.releaseRequests()
        await run.value

        #expect(harness.controller.consumers.isEmpty && viewModel.liveTask == nil)
        #expect(harness.chat.readMarks.isEmpty && viewModel.members.isEmpty)
        #expect(harness.errorCenter.current == nil && harness.recorder.kinds == [.chatOpened])
        #expect(viewModel.room.messages.isEmpty && !viewModel.historyLoadFailed,
                "a request cancelled while in flight answers nothing, as a URLSession task's does, and that is no failure")
    }

    /// Back and in again on one view model: one open recorded, one catch-up per appear, one live task at a time.
    @Test func aSecondAppearAfterAPopRunsOneLoadAndOneLiveTask() async {
        let (harness, viewModel) = await makeHarness(cached: [first])

        await viewModel.appear()
        await viewModel.cancel()
        await viewModel.appear()

        #expect(harness.recorder.kinds == [.chatOpened])
        #expect(harness.controller.openRoom?.groupID == "g")
        #expect(harness.chat.newerRequests.count == 2 && harness.chat.readMarks.count == 1)
        await settle(until: { harness.controller.consumers.count == 1 })
        harness.transport.post(.message(second), to: .room(groupID: "g", epoch: 1))
        await settle(until: { viewModel.room.messages.count == 2 })
    }

    @Test func groupDeletedMarksTheRoomGone() async {
        let (harness, viewModel) = await makeHarness(cached: [first])
        await viewModel.appear()
        let flushed = harness.chat.readMarks.count

        harness.transport.post(.groupDeleted(groupID: "g"), to: .room(groupID: "g", epoch: 1))
        await settle(until: { viewModel.isGone })

        #expect(harness.cache.room(for: "g") == nil, "the controller's routing drops it")
        await viewModel.cancel()
        #expect(harness.chat.readMarks.count == flushed, "a dropped room has no id to flush")
    }

    /// The first page failed for a reason that leaves the room the caller's: the empty state offers Try again, which
    /// runs `loadHistory()` alone and fills the room; the live task is already running from the failed appear.
    @Test func aFailedFirstHistoryLoadOffersTryAgain() async {
        let (harness, viewModel) = await makeHarness()
        harness.chat.pageError = AppError.chatUnavailable
        #expect(viewModel.isAwaitingHistory, "the first frame comes before the load: an empty room is not empty yet")

        await viewModel.appear()

        #expect(viewModel.rows.isEmpty && viewModel.historyLoadFailed)
        #expect(!viewModel.isAwaitingHistory, "a failed first load is not awaited: Try again shows")
        #expect(!viewModel.isLoadingHistory && !viewModel.isGone)
        #expect(viewModel.historyLoadsFinished == 1, "a failed load ends too, for the transcript's arrivals")
        #expect(harness.errorCenter.current?.error == .chatUnavailable)
        #expect(harness.cache.room(for: "g")?.hasHistory == false, "the stub stays cached, so a live line has a room")
        #expect(viewModel.liveTask != nil, "the live task started after the failed page; Try again needs the history alone")

        harness.chat.pageError = nil
        harness.chat.newestPages = [.fixture([first])]
        await viewModel.loadHistory()

        #expect(!viewModel.historyLoadFailed)
        #expect(viewModel.room.messages.map(\.id) == ["m1"])
        #expect(harness.chat.newestGroupIDs == ["g", "g"], "Try again asks for the first page again")
    }

    /// Whether the transcript waits for the history: until a load brings it in, rows or none; a load cancelled by
    /// leaving the screen still leaves it awaited, since the way back loads again.
    @Test func theHistoryIsAwaitedUntilALoadBringsItIn() async {
        let (harness, viewModel) = await makeHarness()
        harness.chat.holdsRequests = true
        let cancelled = Task { await viewModel.loadHistory() }
        await settle(until: { harness.chat.isHolding })
        cancelled.cancel()
        harness.chat.releaseRequests()
        await cancelled.value

        #expect(viewModel.isAwaitingHistory && !viewModel.hasLoadedHistory && viewModel.historyLoadsFinished == 1)

        await viewModel.loadHistory()
        #expect(!viewModel.isAwaitingHistory && viewModel.hasLoadedHistory && viewModel.rows.isEmpty,
                "an empty page brings the history in: the empty state shows")

        let (second, filled) = await makeHarness()
        second.chat.newestPages = [.fixture([first])]
        await filled.loadHistory()
        #expect(!filled.isAwaitingHistory && filled.hasLoadedHistory && !filled.rows.isEmpty)
    }

    @Test func aPageThatEndsRoomAccessIsGoneNotFailed() async {
        let (harness, viewModel) = await makeHarness()
        harness.chat.pageError = AppError.notAMember

        await viewModel.appear()

        #expect(viewModel.isGone && !viewModel.historyLoadFailed, "the screen leaves; there is nothing to try again")
        #expect(viewModel.isAwaitingHistory, "no empty state on the way out")
    }

    /// A page that ended the room's access is a refusal the room expects: a warning, never an error line.
    @Test func aPageThatEndsRoomAccessIsLoggedAtWarning() async {
        let (harness, viewModel) = await makeHarness()
        harness.chat.pageError = AppError.notAMember

        await viewModel.appear()

        #expect(harness.chatLogs(.warning).filter { $0 == "Loading messages failed in group g: notAMember" }.count == 1)
        #expect(!harness.chatLogs(.error).contains { $0.hasPrefix("Loading messages failed") })
    }

    /// A page the backend could not serve is a fault: an error line, never a warning.
    @Test func aFailedPageStaysAnErrorLine() async {
        let (harness, viewModel) = await makeHarness()
        harness.chat.pageError = AppError.chatUnavailable

        await viewModel.appear()

        #expect(harness.chatLogs(.error).filter { $0 == "Loading messages failed in group g: chatUnavailable" }.count == 1)
        #expect(!harness.chatLogs(.warning).contains { $0.hasPrefix("Loading messages failed") })
    }

    /// The screen left while the first page was out and the request then answered an error: no Try again on a screen
    /// nobody sees, no popup.
    @Test func aCancelledHistoryLoadIsNotAFailure() async {
        let (harness, viewModel) = await makeHarness()
        harness.chat.pageError = AppError.chatUnavailable
        harness.chat.holdsRequests = true
        let run = Task { await viewModel.appear() }
        await settle(until: { harness.chat.newestGroupIDs == ["g"] })

        run.cancel()
        harness.chat.releaseRequests()
        await run.value

        #expect(!viewModel.historyLoadFailed && !viewModel.isLoadingHistory)
        #expect(viewModel.rows.isEmpty && harness.errorCenter.current == nil)
    }
}
