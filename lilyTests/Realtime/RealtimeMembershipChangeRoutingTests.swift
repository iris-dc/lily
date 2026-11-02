import Foundation
import Testing
@testable import lily

/// `membership_changed` kinds on the caller's own channel that this build does not know (the known kinds are routed in
/// `RealtimeSessionControllerRoutingTests.userChannelEventsMoveMembership`).
@MainActor
struct RealtimeMembershipChangeRoutingTests {
    private let userChannel = RealtimeChannel.user(sub: TestFixtures.user.id)

    /// A kind this build does not know takes the not-ending branch: Mine is refetched, the epoch noted, the room kept.
    @Test func anUnseenMembershipChangeKindRefreshesMineAndKeepsTheRoom() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success([.fixture(id: "g2", role: .member)])
        await harness.connect()
        let version = harness.changes.version

        let muted = MembershipChange(groupId: "g2", change: .unknown("muted"), role: nil, channelEpoch: 3)
        harness.transport.post(.membershipChanged(muted), to: userChannel)
        await settle(until: { harness.changes.version == version + 1 })

        #expect(harness.store.groups.map(\.id) == ["g2"])
        await settle(until: { harness.controller.subscribedRooms["g2"] == 3 })
        #expect(harness.controller.subscribedRooms == ["g2": 3])
        #expect(harness.chatLogs(.info).mentioning("muted", "g2").count == 1)
    }
}
