import Foundation
import Testing
@testable import lily

/// A live line moves its room to the top of Mine, cached or not, so the Chats list shows the latest conversation first.
@MainActor
struct RealtimeRoomActivityTests {
    @Test func aLiveMessageMovesItsRoomToTheTopOfMine() async {
        let harness = RealtimeHarness()
        let earlier = Date(timeIntervalSince1970: 1_700_000_000)
        harness.groups.result = .success([.fixture(id: "g1", lastMessageAt: earlier, role: .member),
                                          .fixture(id: "g2", createdAt: earlier - 100, role: .member)])
        await harness.connect()
        await harness.store.reload()
        #expect(harness.store.groups.map(\.id) == ["g1", "g2"])

        harness.transport.post(.message(.fixture(id: "m1", groupID: "g2", sentAt: earlier + 60)),
                               to: .room(groupID: "g2", epoch: 1))
        await settle(until: { harness.store.groups.first?.id == "g2" })

        #expect(harness.store.groups.map(\.id) == ["g2", "g1"])
        #expect(harness.store.groups.first?.lastMessageId == "m1")
    }
}
