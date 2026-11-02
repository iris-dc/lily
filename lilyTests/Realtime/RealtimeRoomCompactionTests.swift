import Foundation
import Testing
@testable import lily

/// Which room a live line compacts: the open room and the room last looked at keep every page their reader loaded;
/// every other room keeps the cache's newest rows. A room dropped, or a session that ended, forgets the room last
/// looked at.
@MainActor
struct RealtimeRoomCompactionTests {
    private let limit = AppConfig.Chat.roomCacheLimit
    private let visited = SportGroup.fixture(id: "g", channelEpoch: 1, role: .member)

    /// One page more than the cache keeps, so a live line shows whether the room was trimmed.
    private func rows(in groupID: String) -> [ChatMessage] {
        (1...(limit + 1)).map { .fixture(id: String(format: "\(groupID)%04d", $0), groupID: groupID) }
    }

    /// A connected harness whose reader looked at `visited` (plus `others`) and left it.
    private func makeHarness(others: [SportGroup] = []) async -> RealtimeHarness {
        let harness = RealtimeHarness()
        harness.groups.result = .success([visited] + others)
        harness.cache.store(.fixture(groupID: "g", messages: rows(in: "g")), for: "g")
        await harness.connect()
        let viewModel = harness.makeChatViewModel(for: visited)
        await viewModel.appear()
        await viewModel.cancel()
        return harness
    }

    private func postLine(_ harness: RealtimeHarness, in groupID: String) {
        harness.transport.post(.message(.fixture(id: "\(groupID)9999", groupID: groupID)),
                               to: .room(groupID: groupID, epoch: 1))
    }

    /// A live line in the room last looked at keeps its rows, since its reader may be coming back to their place; any
    /// other covered room is trimmed to what the cache keeps, as before. Both earn the unread dot.
    @Test func aLiveLineInTheRoomLastLookedAtDoesNotTrimIt() async {
        let harness = await makeHarness(others: [.fixture(id: "x", role: .member)])
        harness.cache.store(.fixture(groupID: "x", messages: rows(in: "x")), for: "x")

        postLine(harness, in: "g")
        postLine(harness, in: "x")
        await settle(until: { harness.unread.unreadGroupIDs.count == 2 })

        #expect(harness.cache.room(for: "g")?.messages.count == limit + 2, "the room last looked at keeps its pages")
        #expect(harness.cache.room(for: "x")?.messages.count == limit, "a room never open is trimmed by its line")
        #expect(harness.unread.unreadGroupIDs == ["g", "x"])
    }

    /// A room the caller left and rejoined starts over: dropping it forgot that it was the room last looked at, so a
    /// line in it trims it like any covered room.
    @Test func aDroppedRoomIsNoLongerTheRoomLastLookedAt() async {
        let harness = await makeHarness()
        harness.controller.removeGroupLocally("g", reason: "left")
        #expect(harness.controller.lastOpenRoomID == nil)

        harness.store.add(visited)
        harness.controller.syncRooms()
        harness.cache.store(.fixture(groupID: "g", messages: rows(in: "g")), for: "g")
        await settle(until: { harness.controller.subscribedRooms["g"] == 1 })
        postLine(harness, in: "g")
        await settle(until: { harness.unread.unreadGroupIDs == ["g"] })

        #expect(harness.cache.room(for: "g")?.messages.count == limit, "a rejoined room is trimmed by its line")
    }

    /// The next session's reader has no place to come back to: a user change forgets the room last looked at, and a
    /// line in it trims it.
    @Test func aUserChangeForgetsTheRoomLastLookedAt() async {
        let harness = await makeHarness()

        await harness.controller.setDesired(active: true, user: AuthUser(id: "u-2", email: nil))
        #expect(harness.controller.lastOpenRoomID == nil && harness.controller.state == .connected)
        await settle(until: { harness.controller.subscribedRooms["g"] == 1 })
        postLine(harness, in: "g")
        await settle(until: { harness.unread.unreadGroupIDs == ["g"] })

        #expect(harness.cache.room(for: "g")?.messages.count == limit, "the old session's room is trimmed by its line")
    }
}
