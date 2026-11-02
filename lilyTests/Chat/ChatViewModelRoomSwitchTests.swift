import Foundation
import Testing
@testable import lily

/// An iPad switch between two rooms where the next room's `appear()` registered before the last room's `cancel()`: the
/// room on screen stays the open one whatever the room that left learns meanwhile.
@MainActor
struct ChatViewModelRoomSwitchTests {
    private let group = SportGroup.fixture(id: "g", channelEpoch: 1, role: .member)
    private let other = SportGroup.fixture(id: "h", channelEpoch: 1, role: .member)
    private let first = ChatMessage.fixture(id: "m1")

    /// The switch caught half-way: `leaving` (room g) is open and live, `arriving` (room h) registered as the open room
    /// and waits on its first page (`holdsRequests`), and `leaving.cancel()` has not run yet.
    private struct RoomSwitch {
        let harness: RealtimeHarness
        let leaving: ChatViewModel
        let arriving: ChatViewModel
        let opening: Task<Void, Never>
    }

    private func makeSwitch() async -> RoomSwitch {
        let harness = RealtimeHarness()
        harness.groups.result = .success([group, other])
        harness.cache.store(.fixture(groupID: "g", messages: [first]), for: "g")
        await harness.connect()
        let leaving = harness.makeChatViewModel(for: group)
        let arriving = harness.makeChatViewModel(for: other)
        await leaving.appear()
        harness.chat.holdsRequests = true
        let opening = Task { await arriving.appear() }
        await settle(until: { harness.controller.openRoom?.groupID == "h" })
        return RoomSwitch(harness: harness, leaving: leaving, arriving: arriving, opening: opening)
    }

    /// The arriving room's page answers and its live task starts with the room still open.
    private func finish(_ roomSwitch: RoomSwitch) async {
        roomSwitch.harness.chat.releaseRequests()
        await roomSwitch.opening.value
        #expect(roomSwitch.arriving.liveTask != nil && roomSwitch.harness.controller.openRoom?.groupID == "h")
        await roomSwitch.arriving.cancel()
    }

    /// The room that left does not close the one on screen, which stays open, subscribed and caught up.
    @Test func cancellingARoomAnotherScreenReplacedKeepsTheNewRoomOpen() async {
        let roomSwitch = await makeSwitch()

        await roomSwitch.leaving.cancel()
        #expect(roomSwitch.harness.controller.openRoom?.groupID == "h", "the room that left does not close the one on screen")

        await finish(roomSwitch)
    }

    /// The room that left learns a newer epoch (a live line for it) after the next room registered: it resubscribes and
    /// catches up without taking the open room back, so its `cancel()` leaves the room on screen open.
    @Test func anEpochChangeForARoomAnotherScreenReplacedDoesNotTakeTheOpenRoomBack() async {
        let roomSwitch = await makeSwitch()
        let controller = roomSwitch.harness.controller

        roomSwitch.harness.transport.post(.memberJoined(groupID: "g", member: .fixture(), memberCount: 6, channelEpoch: 2),
                                          to: .room(groupID: "g", epoch: 1))
        await settle(until: { roomSwitch.leaving.subscribedEpoch == 2 })
        #expect(controller.openRoom?.groupID == "h", "the epoch change resubscribes g without reopening it")

        await roomSwitch.leaving.cancel()
        #expect(controller.openRoom?.groupID == "h" && controller.lastOpenRoomID == "h")

        await finish(roomSwitch)
    }
}
