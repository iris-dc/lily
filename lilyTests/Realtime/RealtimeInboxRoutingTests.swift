import Foundation
import Testing
@testable import lily

/// `inbox_item` envelopes: the user channel feeds the inbox store, a room channel says nothing about a room.
@MainActor
struct RealtimeInboxRoutingTests {
    private let userChannel = RealtimeChannel.user(sub: TestFixtures.user.id)

    @Test func anInboxItemOnTheUserChannelLandsInTheStore() async {
        let harness = RealtimeHarness()
        await harness.connect()
        let invite = InboxItem.invite(id: "i1")

        harness.transport.post(.inboxItem(invite), to: userChannel)
        await settle(until: { harness.inbox.items == [invite] })

        #expect(harness.inbox.hasUnread, "an item nobody has read lights the badge")

        let accepted = invite.responding(.accepted, at: harness.clock.now)
        harness.transport.post(.inboxItem(accepted), to: userChannel)
        await settle(until: { harness.inbox.items == [accepted] })
        #expect(harness.inbox.items.count == 1, "a status the backend moved replaces the item rather than doubling it")
    }

    @Test func anInboxItemOnARoomChannelIsIgnored() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success([.fixture(id: "g1", role: .member)])
        await harness.connect()
        let sink = harness.sink(for: "g1")

        harness.transport.post(.inboxItem(.invite(id: "i1")), to: .room(groupID: "g1", epoch: 1))
        harness.transport.post(.message(.fixture(id: "m1", groupID: "g1")), to: .room(groupID: "g1", epoch: 1))
        await settle(until: { sink.messageIDs == ["m1"] })

        #expect(harness.inbox.items.isEmpty, "a room says nothing about the inbox")
    }
}
