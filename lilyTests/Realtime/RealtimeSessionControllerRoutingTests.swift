import Foundation
import Testing
@testable import lily

/// Rooms and envelopes: which rooms are subscribed, what arrives on them, and how epochs are followed.
@MainActor
struct RealtimeSessionControllerRoutingTests {
    private let me = TestFixtures.user.id
    private let userChannel = RealtimeChannel.user(sub: TestFixtures.user.id)

    private func mine(_ count: Int) -> [SportGroup] {
        (1...count).map { .fixture(id: "g\($0)", role: .member) }
    }

    @Test func roomsAreTheOpenOnePlusTheMostActiveOfMine() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success(mine(12))
        await harness.connect()

        let limit = AppConfig.Realtime.maxRoomSubscriptions
        #expect(Set(harness.controller.subscribedRooms.keys) == Set((1...limit).map { "g\($0)" }))

        harness.controller.setOpenRoom(RoomSubscription(groupID: "g12", epoch: 1))
        #expect(harness.controller.subscribedRooms.count == limit + 1 && harness.controller.subscribedRooms["g12"] == 1)
        harness.controller.setOpenRoom(RoomSubscription(groupID: "g1", epoch: 1))
        #expect(harness.controller.subscribedRooms.count == limit, "an open room already in the top set is not doubled")

        harness.controller.setOpenRoom(nil)
        harness.controller.setRooms([RoomSubscription(groupID: "g3", epoch: 2)])
        #expect(harness.controller.subscribedRooms == ["g3": 2])
        await harness.yield()
        #expect(Set(harness.transport.subscribedChannels) == [userChannel, .room(groupID: "g3", epoch: 2)])
        #expect(harness.chatLogs(.info).contains("Subscribed to rooms/g3/2"))
    }

    @Test func subscribesBeforeItCatchesUp() async {
        let harness = RealtimeHarness()
        harness.cache.store(.fixture(groupID: "g1", messages: [.fixture(id: "m1", groupID: "g1")]), for: "g1")
        harness.groups.result = .success([.fixture(id: "g1", lastMessageId: "m5", role: .member)])
        var channelsAtCatchUp: [RealtimeChannel] = []
        harness.chat.onRequest = { channelsAtCatchUp = harness.transport.subscribedChannels }

        await harness.connect()

        #expect(harness.chat.newerRequests.map(\.after) == ["m1"])
        #expect(channelsAtCatchUp.contains(.room(groupID: "g1", epoch: 1)))
    }

    /// One Mine load, then only the rooms whose newest message moved past the watermark; uncached rooms need nothing.
    @Test func resumeCatchesUpOnlyTheMovedRooms() async {
        let harness = RealtimeHarness()
        harness.cache.store(.fixture(groupID: "a", messages: [.fixture(id: "m1", groupID: "a")]), for: "a")
        harness.cache.store(.fixture(groupID: "b", messages: [.fixture(id: "m9", groupID: "b")]), for: "b")
        harness.groups.result = .success([.fixture(id: "a", lastMessageId: "m5", role: .member),
                                          .fixture(id: "b", lastMessageId: "m9", role: .member),
                                          .fixture(id: "c", lastMessageId: "m3", role: .member)])

        await harness.connect()

        #expect(harness.chat.newerRequests.map { "\($0.groupID)/\($0.after)" } == ["a/m1"])
        #expect(harness.chat.newestGroupIDs.isEmpty)
        #expect(harness.logger.messages(in: .cache).contains("Catch-up skipped for group b (nothing new)"))
    }

    /// A catch-up page answering a newer epoch than the room subscribed at means a `member_left` was missed while
    /// offline: the room resubscribes at that epoch and is caught up once more, whatever its watermark says, because
    /// the resubscribe reopened the gap the page had just closed.
    @Test func resumeAdoptsTheEpochAPageRevealsAndCatchesUpThatRoomAgain() async {
        let harness = RealtimeHarness()
        harness.cache.store(.fixture(groupID: "g1", messages: [.fixture(id: "m1", groupID: "g1")]), for: "g1")
        harness.groups.result = .success([.fixture(id: "g1", lastMessageId: "m5", role: .member)])
        harness.chat.epoch = 2
        harness.chat.newerPages = [.fixture([.fixture(id: "m5", groupID: "g1")], epoch: 2)]

        await harness.connect()

        #expect(harness.controller.subscribedRooms["g1"] == 2)
        #expect(harness.chatLogs(.info).contains("Epoch changed for group g1: 1 -> 2"))
        #expect(harness.chat.newerRequests.map(\.after) == ["m1", "m5"], "the second pass starts where the first left off")
        await harness.yield()
        #expect(Set(harness.transport.subscribedChannels) == [userChannel, .room(groupID: "g1", epoch: 2)])
    }

    @Test func aMemberLeftIsTrustedAndResubscribedWithJitter() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success([.fixture(id: "g1", role: .member)])
        harness.cache.store(.fixture(groupID: "g1"), for: "g1")
        await harness.connect()

        harness.transport.post(.memberLeft(groupID: "g1", userID: "u-9", channelEpoch: 2, memberCount: 100),
                               to: .room(groupID: "g1", epoch: 1))
        await settle(until: { harness.sleep.held.contains(.seconds(1.0)) })

        #expect(harness.controller.subscribedRooms["g1"] == 1 && harness.groups.fetchedGroupIDs.isEmpty)
        harness.sleep.release { $0 == .seconds(1.0) }
        await settle(until: { harness.controller.subscribedRooms["g1"] == 2 })
        #expect(harness.cache.room(for: "g1")?.channelEpoch == 2)
        #expect(harness.chatLogs(.info).contains("Epoch changed for group g1: 1 -> 2"))
        await harness.yield()
        #expect(!harness.transport.subscribedChannels.contains(.room(groupID: "g1", epoch: 1)))
    }

    @Test func aRefusedSubscribeRefetchesTheGroupAndResubscribes() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success([.fixture(id: "g1", role: .member)])
        await harness.connect()
        harness.groups.result = .success([.fixture(id: "g1", channelEpoch: 3, role: .member)])

        harness.transport.finish(.room(groupID: "g1", epoch: 1), throwing: .subscribeRefused)
        await settle(until: { harness.controller.subscribedRooms["g1"] == 3 })

        #expect(harness.groups.fetchedGroupIDs == ["g1"] && harness.controller.state == .connected)
        #expect(harness.store.groups.first?.channelEpoch == 3)
    }

    /// A refetch that answers the refused epoch again would be refused again: the room waits for the next sync.
    @Test func aRefusedSubscribeAtAnUnchangedEpochIsNotRetried() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success([.fixture(id: "g1", role: .member)])
        await harness.connect()

        harness.transport.finish(.room(groupID: "g1", epoch: 1), throwing: .subscribeRefused)
        await settle(until: { harness.groups.fetchedGroupIDs == ["g1"] })
        await harness.yield()

        #expect(harness.controller.subscribedRooms["g1"] == nil && harness.groups.fetchedGroupIDs == ["g1"])
        #expect(harness.chatLogs(.warning).contains { $0.contains("not retrying") })
    }

    @Test func aRefusedSubscribeForAGroupTheCallerLeftDropsIt() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success([.fixture(id: "g1", role: .member)])
        await harness.connect()
        harness.groups.result = .failure(.groupNotFound)

        harness.transport.finish(.room(groupID: "g1", epoch: 1), throwing: .subscribeRefused)
        await settle(until: { harness.store.groups.isEmpty })

        #expect(harness.controller.subscribedRooms["g1"] == nil)
    }

    @Test func liveMessagesLandInTheCacheAndMarkUnreadRoomsOnly() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success([.fixture(id: "g1", role: .member), .fixture(id: "g2", role: .member)])
        harness.cache.store(.fixture(groupID: "g1"), for: "g1")
        harness.cache.store(.fixture(groupID: "g2"), for: "g2")
        await harness.connect()
        harness.controller.setOpenRoom(RoomSubscription(groupID: "g2", epoch: 1))

        harness.transport.post(.message(.fixture(id: "m1", groupID: "g1")), to: .room(groupID: "g1", epoch: 1))
        harness.transport.post(.message(.fixture(id: "m2", groupID: "g1", senderUserID: me)), to: .room(groupID: "g1", epoch: 1))
        harness.transport.post(.message(.fixture(id: "m3", groupID: "g2")), to: .room(groupID: "g2", epoch: 1))
        harness.transport.post(.messageDeleted(groupID: "g1", id: "m1"), to: .room(groupID: "g1", epoch: 1))
        await settle(until: { harness.cache.room(for: "g2")?.messages.count == 1 })
        await settle(until: { harness.cache.room(for: "g1")?.messages.first?.isDeleted == true })

        #expect(harness.cache.room(for: "g1")?.messages.map(\.id) == ["m1", "m2"])
        #expect(harness.cache.room(for: "g1")?.restWatermark == nil, "live messages never move the watermark")
        #expect(harness.unread.unreadGroupIDs == ["g1"], "own messages and the open room do not count")
    }

    @Test func anEnvelopeOfAnotherGroupIsDropped() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success([.fixture(id: "g1", role: .member)])
        harness.cache.store(.fixture(groupID: "g1"), for: "g1")
        await harness.connect()

        harness.transport.post(.message(.fixture(id: "x1", groupID: "other")), to: .room(groupID: "g1", epoch: 1))
        await settle(until: { harness.chatLogs(.warning).contains { $0.contains("another group") } })

        #expect(harness.cache.room(for: "g1")?.messages.isEmpty == true)
    }

    @Test func beingRemovedDropsTheGroupEverywhere() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success([.fixture(id: "g1", role: .member)])
        harness.cache.store(.fixture(groupID: "g1"), for: "g1")
        harness.unread.markUnread(groupID: "g1", messageID: "m0")
        await harness.connect()
        let version = harness.changes.version
        let stream = harness.controller.envelopes(for: "g1")
        let delivered = Task { await stream.first { _ in true } }

        harness.transport.post(.memberLeft(groupID: "g1", userID: me, channelEpoch: 2, memberCount: 4),
                               to: .room(groupID: "g1", epoch: 1))
        await settle(until: { harness.store.groups.isEmpty })

        #expect(harness.cache.room(for: "g1") == nil && harness.unread.unreadGroupIDs.isEmpty)
        #expect(harness.controller.subscribedRooms["g1"] == nil && harness.changes.version == version + 1)
        #expect(await delivered.value != nil, "the open chat still hears about it")
    }

    @Test func userChannelEventsMoveMembership() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success([.fixture(id: "g1", role: .member), .fixture(id: "g2", role: .member)])
        harness.cache.store(.fixture(groupID: "g1"), for: "g1")
        await harness.connect()
        let version = harness.changes.version

        let removed = MembershipChange(groupId: "g1", change: .removed, role: nil, channelEpoch: 2)
        let promoted = MembershipChange(groupId: "g2", change: .roleChanged, role: .admin, channelEpoch: 1)
        harness.transport.post(.membershipChanged(removed), to: userChannel)
        harness.transport.post(.membershipChanged(promoted), to: userChannel)
        await settle(until: { harness.changes.version == version + 2 })

        #expect(harness.store.groups.map(\.id) == ["g2"] && harness.cache.room(for: "g1") == nil)
        #expect(harness.controller.subscribedRooms == ["g2": 1])
    }

    @Test func groupDeletedAndGroupUpdatedReachMine() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success([.fixture(id: "g1", role: .member), .fixture(id: "g2", role: .member)])
        await harness.connect()

        harness.transport.post(.groupDeleted(groupID: "g1"), to: .room(groupID: "g1", epoch: 1))
        // The broadcast carries no membership: one payload reaches every member.
        harness.transport.post(.groupUpdated(.fixture(id: "g2", name: "Renamed", channelEpoch: 2)),
                               to: .room(groupID: "g2", epoch: 1))
        await settle(until: { harness.controller.subscribedRooms == ["g2": 2] })

        #expect(harness.store.groups.map(\.name) == ["Renamed"])
        #expect(harness.store.groups.first?.role == .member, "the stored membership survives the broadcast")
    }

    @Test func ensureSubscribedWaitsOutAPendingResubscribe() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success([.fixture(id: "g1", role: .member)])
        await harness.connect()
        harness.transport.post(.memberLeft(groupID: "g1", userID: "u-9", channelEpoch: 2, memberCount: 50),
                               to: .room(groupID: "g1", epoch: 1))
        await settle(until: { harness.sleep.held.contains(.seconds(0.5)) })

        let ensured = Task { await harness.controller.ensureSubscribed(RoomSubscription(groupID: "g1", epoch: 2)) }
        await harness.yield()
        #expect(harness.controller.subscribedRooms["g1"] == 1, "still waiting for the jitter")
        harness.sleep.release { $0 == .seconds(0.5) }
        await ensured.value

        #expect(harness.controller.subscribedRooms["g1"] == 2)
        await harness.controller.ensureSubscribed(RoomSubscription(groupID: "g1", epoch: 5))
        #expect(harness.controller.subscribedRooms["g1"] == 5, "a newer epoch from a response is adopted at once")
    }
}
