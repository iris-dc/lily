import Foundation
import Testing
@testable import lily

/// What a subscription carries and how each `subscribe_error` answer maps, per the agreed rules: a failed server-side
/// check retries with backoff, `Unauthorized` is `.subscribeRefused` (the controller refetches the group), anything
/// else is `.unavailable` (the controller stops and falls to catch-up).
@MainActor
struct AppSyncRealtimeTransportSubscribeTests {
    @Test func everySubscribeCarriesAFreshTokenAndTheChannelPath() async throws {
        let harness = AppSyncTransportHarness()
        try await harness.connect()

        harness.tokens.token = "token-2"
        _ = await harness.subscribe(to: .room(groupID: "g1", epoch: 3))
        let room = try #require(harness.socket.sent(ofType: "subscribe").last)
        #expect(room["channel"] as? String == "rooms/g1/3")
        #expect((room["authorization"] as? [String: String])?["Authorization"] == "token-2")

        harness.tokens.token = "token-3"
        _ = await harness.subscribe(to: .user(sub: "sub-1"))
        let user = try #require(harness.socket.sent(ofType: "subscribe").last)
        #expect(user["channel"] as? String == "users/sub-1")
        #expect((user["authorization"] as? [String: String])?["Authorization"] == "token-3")
        #expect((user["authorization"] as? [String: String])?["host"] == "abc.appsync-api.eu-central-1.amazonaws.com")
        await harness.transport.disconnect()
    }

    @Test func dataFramesDecodeToEnvelopesOnTheirOwnStream() async throws {
        let harness = AppSyncTransportHarness()
        try await harness.connect()
        let (reader, id) = await harness.subscribe(to: .room(groupID: "g1", epoch: 1))

        harness.socket.feed(["type": "subscribe_success", "id": id])
        harness.socket.feed(["type": "data", "id": id,
                             "event": FakeEventsSocket.json(["type": "group_deleted", "groupId": "g1"])])
        harness.socket.feed(["type": "data", "id": "someone-else",
                             "event": FakeEventsSocket.json(["type": "group_deleted", "groupId": "g9"])])
        harness.socket.feed(["type": "data", "id": id, "event": "not json"])
        harness.socket.feed(["type": "data", "id": id,
                             "event": FakeEventsSocket.json(["type": "message_deleted", "groupId": "g1",
                                                             "messageId": "m1"])])

        await settle(until: { reader.received.count == 2 })
        #expect(reader.received == [.groupDeleted(groupID: "g1"), .messageDeleted(groupID: "g1", id: "m1")])
        #expect(!reader.hasEnded, "an undecodable event never ends the stream")
        #expect(harness.logger.messages(in: .chat, at: .warning).mentioning("undecodable event").count == 1)
        await harness.transport.disconnect()
    }

    @Test func aSubscriptionCheckFailureRetriesWithBackoffAndAFreshToken() async throws {
        let harness = AppSyncTransportHarness()
        try await harness.connect()
        let (reader, id) = await harness.subscribe(to: .room(groupID: "g1", epoch: 1))

        harness.tokens.token = "token-2"
        harness.socket.feed(["type": "subscribe_error", "id": id,
                             "errors": [["errorType": "SubscriptionCheckFailed", "message": "try again"]]])
        let backoff = AppConfig.Realtime.reconnectBackoffSeconds[0] * (1 + AppConfig.Realtime.reconnectJitter)
        await settle(until: { harness.sleep.held.map(\.seconds).contains(backoff) })
        #expect(harness.logger.messages(in: .chat, at: .warning).mentioning("Subscribe check failed").count == 1)

        harness.sleep.release { $0.seconds == backoff }
        await settle(until: { harness.socket.sent(ofType: "subscribe").count == 2 })
        let retried = try #require(harness.socket.sent(ofType: "subscribe").last)
        #expect(retried["id"] as? String == id, "the retry keeps its id")
        #expect((retried["authorization"] as? [String: String])?["Authorization"] == "token-2")
        #expect(!reader.hasEnded)

        // A success resets the walk: the next failure waits the first backoff again.
        harness.socket.feed(["type": "subscribe_success", "id": id])
        harness.socket.feed(["type": "subscribe_error", "id": id,
                             "errors": [["errorType": "SubscriptionCheckFailed", "message": "try again"]]])
        await settle(until: { harness.sleep.held.map(\.seconds).contains(backoff) })
        await harness.transport.disconnect()
    }

    @Test func exhaustedSubscribeRetriesGiveTheConnectionUp() async throws {
        let harness = AppSyncTransportHarness()
        try await harness.connect()
        let (reader, id) = await harness.subscribe(to: .room(groupID: "g1", epoch: 1))
        let watchdogWindow = AppConfig.Realtime.defaultKeepAliveTimeout

        for attempt in 0..<AppConfig.Realtime.subscribeRetryLimit {
            harness.socket.feed(["type": "subscribe_error", "id": id,
                                 "errors": [["errorType": "SubscriptionCheckFailed", "message": "no"]]])
            await settle(until: { harness.sleep.held.contains { $0.seconds < watchdogWindow } })
            harness.sleep.release { $0.seconds < watchdogWindow }
            await settle(until: { harness.socket.sent(ofType: "subscribe").count == attempt + 2 })
        }
        harness.socket.feed(["type": "subscribe_error", "id": id,
                             "errors": [["errorType": "SubscriptionCheckFailed", "message": "no"]]])

        await settle(until: { reader.hasEnded })
        #expect(reader.outcome == .some(.connectionLost))
        await harness.transport.disconnect()
    }

    @Test func anUnauthorizedSubscribeEndsTheStreamRefused() async throws {
        let harness = AppSyncTransportHarness()
        try await harness.connect()
        let (reader, id) = await harness.subscribe(to: .room(groupID: "g1", epoch: 1))

        harness.socket.feed(["type": "subscribe_error", "id": id,
                             "errors": [["errorType": "UnauthorizedException", "message": "not a member"]]])

        await settle(until: { reader.hasEnded })
        #expect(reader.outcome == .some(.subscribeRefused))
        #expect(harness.socket.closeCount == 0, "the connection itself stays")
        await harness.transport.disconnect()
    }

    @Test func anyOtherSubscribeErrorFallsToCatchUp() async throws {
        let harness = AppSyncTransportHarness()
        try await harness.connect()
        let (reader, id) = await harness.subscribe(to: .room(groupID: "g1", epoch: 1))

        harness.socket.feed(["type": "subscribe_error", "id": id,
                             "errors": [["errorType": "Forbidden", "message": "auth mode"]]])

        await settle(until: { reader.hasEnded })
        #expect(reader.outcome == .some(.unavailable))
        #expect(harness.logger.messages(in: .chat, at: .warning).mentioning("catch-up only").count == 1)
        await harness.transport.disconnect()
    }

    /// An `error` frame outside the subscribe flow (a rate limit, a malformed frame): the named stream falls to
    /// catch-up; one naming no subscription is only logged.
    @Test func anErrorFrameNamingTheSubscriptionFallsToCatchUp() async throws {
        let harness = AppSyncTransportHarness()
        try await harness.connect()
        let (reader, id) = await harness.subscribe(to: .room(groupID: "g1", epoch: 1))

        harness.socket.feed(["type": "error", "errors": [["errorType": "LimitExceededError", "message": "slow"]]])
        harness.socket.feed(["type": "error", "id": id,
                             "errors": [["errorType": "LimitExceededError", "message": "slow"]]])

        await settle(until: { reader.hasEnded })
        #expect(reader.outcome == .some(.unavailable))
        #expect(harness.logger.messages(in: .chat, at: .warning).mentioning("Realtime error frame").count == 1,
                "the frame naming no subscription is only logged")
        await harness.transport.disconnect()
    }

    @Test func aConsumerLeavingUnsubscribesItsChannel() async throws {
        let harness = AppSyncTransportHarness()
        try await harness.connect()
        let (reader, id) = await harness.subscribe(to: .room(groupID: "g1", epoch: 1))

        reader.cancel()

        await settle(until: { harness.socket.sent(ofType: "unsubscribe").count == 1 })
        #expect(harness.socket.sent(ofType: "unsubscribe").first?["id"] as? String == id)
        await harness.transport.disconnect()
    }

    @Test func subscribingWithoutAConnectionEndsAtOnce() async {
        let harness = AppSyncTransportHarness()
        let reader = EnvelopeStreamReader(harness.transport.subscribe(to: .room(groupID: "g1", epoch: 1)))

        await settle(until: { reader.hasEnded })
        #expect(reader.outcome == .some(.connectionLost))
        #expect(harness.socket.sentFrames.isEmpty)
    }
}
