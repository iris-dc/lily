import Foundation
import Testing
@testable import lily

/// Subscriptions and resubscribes, which the routing suite, near its limits, cannot hold: a stream's end told from a
/// cancelled predecessor's on the same channel, `ensureSubscribed` outlasting every jittered resubscribe, what a
/// refused subscribe's refetch does when it fails or answers a group the caller is out of, a `member_left` that is
/// stale or that supersedes a pending jitter, and a message for a room the cache never held.
@MainActor
struct RealtimeResubscribeTests {
    private let userChannel = RealtimeChannel.user(sub: TestFixtures.user.id)
    private let renewal = Duration.seconds(AppConfig.Realtime.maxConnectionAge)

    /// Closing and reopening a room in one turn (the open room alone holds it) cancels its stream and opens a second
    /// one on the same channel; the cancelled stream's clean end is its own, not a lost connection.
    @Test func aSameChannelResubscribeInOneTurnIsNotALostConnection() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success(RealtimeHarness.mine(1))
        harness.cache.store(.fixture(groupID: "g2"), for: "g2")
        await harness.connect()
        let room = RoomSubscription(groupID: "g2", epoch: 1)
        let channel = RealtimeChannel.room(groupID: "g2", epoch: 1)
        harness.controller.setOpenRoom(room)
        harness.controller.setOpenRoom(nil)
        harness.controller.setOpenRoom(room)
        await harness.yield()

        #expect(harness.controller.state == .connected && harness.transport.disconnectCount == 0)
        #expect(harness.controller.subscribedRooms == ["g1": 1, "g2": 1])
        #expect(harness.transport.subscriptionLog.filter { $0 == channel }.count == 2)
        #expect(harness.transport.subscribedChannels.filter { $0 == channel }.count == 1, "the cancelled stream is gone")
        #expect(harness.transport.subscribedChannels.contains(userChannel), "the connection was left alone")
        #expect(harness.sleep.held == [renewal], "no backoff timer was armed")
        #expect(!harness.chatLogs(.info).contains("Chat connection closed (connection lost)"))
        #expect(harness.chatLogs(.debug).contains("Unsubscribed from rooms/g2/1"))

        harness.transport.post(.message(.fixture(id: "m1", groupID: "g2")), to: channel)
        await harness.yield()
        #expect(harness.cache.room(for: "g2")?.messages.map(\.id) == ["m1"], "the second stream is the live one")
    }

    /// A second `member_left` with a newer epoch cancels the pending jitter and arms another; a caller already waiting
    /// in `ensureSubscribed` waits that one out too, so the room is at the newest epoch when the call returns.
    @Test func ensureSubscribedWaitsOutEveryPendingResubscribe() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success(RealtimeHarness.mine(1))
        harness.cache.store(.fixture(groupID: "g1"), for: "g1")
        await harness.connect()
        let channel = RealtimeChannel.room(groupID: "g1", epoch: 1)
        harness.transport.post(.memberLeft(groupID: "g1", userID: "u-9", channelEpoch: 2, memberCount: 50), to: channel)
        await settle(until: { harness.sleep.held.contains(.seconds(0.5)) })
        let epochOnReturn = Task {
            await harness.controller.ensureSubscribed(RoomSubscription(groupID: "g1", epoch: 2))
            return harness.controller.subscribedRooms["g1"]
        }
        await harness.yield()

        harness.transport.post(.memberLeft(groupID: "g1", userID: "u-8", channelEpoch: 3, memberCount: 100), to: channel)
        await settle(until: { harness.sleep.held.contains(.seconds(1.0)) })
        await harness.yield()
        #expect(!harness.sleep.held.contains(.seconds(0.5)), "the first jitter was cancelled")
        #expect(harness.controller.subscribedRooms["g1"] == 1, "still waiting for the second jitter")

        harness.sleep.release { $0 == .seconds(1.0) }
        let epoch = await epochOnReturn.value
        #expect(epoch == 3, "the waiter outlasted the cancelled first timer")
        #expect(harness.controller.subscribedRooms["g1"] == 3)
    }

    /// A refetch that fails leaves the refused room unsubscribed, Mine as it was and the user uninformed (a warning
    /// alone); the connection stays, no backoff or jitter is armed, and the next sync subscribes the room again.
    @Test func aFailedRefetchLeavesTheRoomUnsubscribedAndMineUntouched() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success(RealtimeHarness.mine(1))
        await harness.connect()
        harness.groups.result = .failure(.network)

        harness.transport.finish(.room(groupID: "g1", epoch: 1), throwing: .subscribeRefused)
        await settle(until: {
            harness.chatLogs(.warning).contains { $0.hasPrefix("Could not refetch group g1 after a refused subscribe") }
        })

        #expect(harness.controller.subscribedRooms["g1"] == nil)
        #expect(!harness.transport.subscribedChannels.contains(.room(groupID: "g1", epoch: 1)))
        #expect(harness.store.groups.map(\.id) == ["g1"], "Mine is not touched by a failed read")
        #expect(harness.errorCenter.current == nil, "a refetch failure is logged, never shown")
        #expect(harness.controller.state == .connected)
        #expect(harness.groups.fetchedGroupIDs == ["g1"], "one read, no retry loop")
        #expect(harness.sleep.held == [renewal], "no reconnect and no jitter were armed")

        harness.groups.result = .success(RealtimeHarness.mine(1))
        await harness.store.reload()
        harness.controller.syncRooms()
        #expect(harness.controller.subscribedRooms["g1"] == 1, "the room waits for the next sync")
    }

    /// The refetch answers the group without a membership: the caller is out of it, so the room goes everywhere
    /// (Mine, the cache, the epochs, the subscription) and the newer epoch it names is never subscribed.
    @Test func aRefetchedGroupWithoutMembershipIsDropped() async {
        let harness = RealtimeHarness()
        await expectRefetchDrops(harness, answering: .fixture(id: "g1", channelEpoch: 2))
    }

    /// The refetch answers a deleted group the caller is still a member of: dropped the same way.
    @Test func aRefetchedGroupThatWasDeletedIsDropped() async {
        let harness = RealtimeHarness()
        let deleted = SportGroup.fixture(id: "g1",
                                         channelEpoch: 2,
                                         deletedAt: Date(timeIntervalSince1970: 1_800_000_000),
                                         role: .member)
        await expectRefetchDrops(harness, answering: deleted)
    }

    private func expectRefetchDrops(_ harness: RealtimeHarness, answering group: SportGroup) async {
        harness.groups.result = .success(RealtimeHarness.mine(1))
        harness.cache.store(.fixture(groupID: "g1"), for: "g1")
        await harness.connect()
        harness.groups.result = .success([group])

        harness.transport.finish(.room(groupID: "g1", epoch: 1), throwing: .subscribeRefused)
        await settle(until: { harness.store.groups.isEmpty })

        #expect(harness.cache.room(for: "g1") == nil)
        #expect(harness.controller.subscribedRooms["g1"] == nil)
        #expect(harness.controller.knownEpochs["g1"] == nil)
        #expect(harness.chatLogs(.info).contains("Group g1 dropped (no longer a member)"))
        #expect(harness.controller.state == .connected)
        #expect(harness.errorCenter.current == nil)
        #expect(!harness.transport.subscriptionLog.contains(.room(groupID: "g1", epoch: 2)),
                "the newer epoch is never subscribed")
    }

    /// A `member_left` at the subscribed epoch or an older one moves nothing: no jitter, no epoch, no log line.
    @Test func aStaleMemberLeftIsIgnored() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success(RealtimeHarness.mine(1))
        harness.cache.store(.fixture(groupID: "g1"), for: "g1")
        await harness.connect()
        let channel = RealtimeChannel.room(groupID: "g1", epoch: 1)

        harness.transport.post(.memberLeft(groupID: "g1", userID: "u-9", channelEpoch: 1, memberCount: 100), to: channel)
        harness.transport.post(.memberLeft(groupID: "g1", userID: "u-9", channelEpoch: 0, memberCount: 100), to: channel)
        await harness.yield()

        #expect(harness.sleep.held == [renewal], "the renewal alone, no jitter timer")
        #expect(harness.controller.subscribedRooms["g1"] == 1)
        #expect(harness.controller.knownEpochs["g1"] == 1)
        #expect(harness.cache.room(for: "g1")?.channelEpoch == 1)
        #expect(!harness.chatLogs(.info).contains { $0.hasPrefix("Epoch changed") })
    }

    /// A newer `member_left` while a jitter is pending cancels that timer and arms its own; the room stays at the old
    /// epoch until the second timer fires and then subscribes at the newest, never at the superseded one.
    @Test func aNewerMemberLeftWhileAJitterIsPendingRearmsIt() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success(RealtimeHarness.mine(1))
        harness.cache.store(.fixture(groupID: "g1"), for: "g1")
        await harness.connect()
        let channel = RealtimeChannel.room(groupID: "g1", epoch: 1)
        harness.transport.post(.memberLeft(groupID: "g1", userID: "u-9", channelEpoch: 2, memberCount: 50), to: channel)
        await settle(until: { harness.sleep.held.contains(.seconds(0.5)) })

        harness.transport.post(.memberLeft(groupID: "g1", userID: "u-8", channelEpoch: 3, memberCount: 100), to: channel)
        await settle(until: { harness.sleep.held.contains(.seconds(1.0)) && !harness.sleep.held.contains(.seconds(0.5)) })

        #expect(harness.controller.subscribedRooms["g1"] == 1, "still at the old epoch while the jitter runs")
        #expect(harness.controller.knownEpochs["g1"] == 3)
        harness.sleep.release { $0 == .seconds(1.0) }
        await settle(until: { harness.controller.subscribedRooms["g1"] == 3 })
        #expect(!harness.transport.subscriptionLog.contains(.room(groupID: "g1", epoch: 2)),
                "the superseded epoch was never subscribed")
    }

    /// A message for a room the cache never held (a room never opened) still lights its dot: the unread set is its
    /// own, and the cache is left alone so no late page can find a room nobody opened.
    @Test func aMessageForARoomNeverOpenedLightsItsDot() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success(RealtimeHarness.mine(1))
        await harness.connect()

        harness.transport.post(.message(.fixture(id: "m1", groupID: "g1", senderUserID: "u-9")),
                               to: .room(groupID: "g1", epoch: 1))
        await settle(until: { harness.unread.hasUnread(groupID: "g1") })

        #expect(harness.cache.room(for: "g1") == nil, "the dot never depends on the cache")
    }
}
