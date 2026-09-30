import Foundation
import Testing
@testable import lily

/// A conversation the other side started arrives as a `membership_changed(joined)` for a group Mine has never seen.
@MainActor
struct RealtimeConversationRoutingTests {
    private let userChannel = RealtimeChannel.user(sub: TestFixtures.user.id)

    /// The event marks Mine stale (the change tracker) and nothing else: no group read, no epoch warning, no
    /// subscription until the reload lists the room, which is then subscribed at the epoch the event named.
    @Test func aJoinedMembershipForAnUnknownGroupOnlyMarksMineStale() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success([.fixture(id: "g1", role: .member)])
        await harness.connect()
        let version = harness.changes.version
        let joined = MembershipChange(groupId: "dm", change: .joined, role: .member, channelEpoch: 1)

        harness.transport.post(.membershipChanged(joined), to: userChannel)
        await settle(until: { harness.changes.version == version + 1 })

        #expect(harness.controller.subscribedRooms == ["g1": 1] && harness.groups.fetchedGroupIDs.isEmpty)
        #expect(harness.chatLogs(.warning).isEmpty && harness.chatLogs(.error).isEmpty && harness.errorCenter.current == nil)
        #expect(harness.store.groups.map(\.id) == ["g1"], "Mine shows the room once it reloads")

        harness.groups.result = .success([.conversationFixture(id: "dm"), .fixture(id: "g1", role: .member)])
        await harness.store.reload()
        harness.controller.syncRooms()
        #expect(harness.controller.subscribedRooms == ["g1": 1, "dm": 1])
    }
}
