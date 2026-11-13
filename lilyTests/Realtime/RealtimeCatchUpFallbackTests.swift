import Foundation
import Testing
@testable import lily

/// A channel the API refuses outright (a stream ending `.unavailable`: the kill switch flipped under the open socket)
/// stops the connection and falls to catch-up: no resubscribe, no reconnect timer, no popup.
@MainActor
struct RealtimeCatchUpFallbackTests {
    @Test func aRefusedRoomStreamFallsToCatchUpWithoutAReconnect() async {
        let harness = RealtimeHarness()
        let group = SportGroup.fixture(id: "g1", role: .member)
        harness.groups.result = .success([group])
        // An open room is always cached (the chat screen cached it when it opened); only a cached room is caught up.
        harness.cache.store(.fixture(groupID: "g1", messages: [.fixture(id: "m1", groupID: "g1")]), for: "g1")
        await harness.connect()
        harness.controller.setOpenRoom(RoomSubscription(group: group))
        #expect(harness.controller.subscribedRooms == ["g1": 1])
        let pagesBefore = harness.chat.newerRequests.count

        harness.transport.finish(.room(groupID: "g1", epoch: 1), throwing: .unavailable)
        await settle(until: { harness.chat.newerRequests.count == pagesBefore + 1 })

        #expect(harness.controller.state == .unavailable)
        #expect(harness.transport.disconnectCount == 1)
        await settle(until: { harness.sleep.held.isEmpty })
        #expect(harness.controller.reconnectTask == nil, "no reconnect is armed")
        #expect(harness.errorCenter.current == nil, "no popup")
        #expect(harness.chatLogs(.info).mentioning("catching up the open room g1").count == 1)
        #expect(harness.chatLogs(.warning).mentioning("catch-up only").count == 1)
    }

    @Test func aRefusedUserChannelFallsToCatchUpUntilTheNextForeground() async {
        let harness = RealtimeHarness()
        await harness.connect()

        harness.transport.finish(.user(sub: TestFixtures.user.id), throwing: .unavailable)
        await settle(until: { harness.controller.state == .unavailable && harness.sleep.held.isEmpty })
        #expect(harness.controller.reconnectTask == nil && harness.errorCenter.current == nil)
        #expect(harness.transport.disconnectCount == 1)

        await harness.controller.resume()
        #expect(harness.controller.state == .connected && harness.transport.connectCount == 2)
    }
}
