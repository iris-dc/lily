import Foundation
import Testing
@testable import lily

/// The AppSync transport's connection: the token on the upgrade, the ack, the refusal mapping and the teardown.
@MainActor
struct AppSyncRealtimeTransportTests {
    @Test func connectSendsTheTokenOnTheUpgradeAndCompletesOnTheAck() async throws {
        let harness = AppSyncTransportHarness()
        try await harness.connect()

        let request = try #require(harness.socket.openRequests.first)
        #expect(request.url == URL(string: "wss://abc.appsync-realtime-api.eu-central-1.amazonaws.com/event/realtime"))
        let header = try #require(request.value(forHTTPHeaderField: "Sec-WebSocket-Protocol"))
        #expect(header.hasPrefix("aws-appsync-event-ws, header-"))
        let auth = try #require(AppSyncTransportHarness.authorization(inHandshake: header))
        #expect(auth["Authorization"] == "token-1" && auth["host"] == "abc.appsync-api.eu-central-1.amazonaws.com")
        #expect(!harness.logger.entries.contains { $0.message.contains("token-1") }, "the token is never logged")
        await harness.transport.disconnect()
    }

    @Test func theEndpointsDeriveFromEitherFormAndKeepACustomDomain() throws {
        let httpForm = URL(string: "https://abc.appsync-api.eu-central-1.amazonaws.com/event")!
        let realtimeForm = URL(string: "https://abc.appsync-realtime-api.eu-central-1.amazonaws.com/event")!
        let fromHTTP = try #require(AppSyncEndpoints(endpoint: httpForm))
        #expect(fromHTTP == AppSyncEndpoints(endpoint: realtimeForm))
        #expect(fromHTTP.socketURL == URL(string: "wss://abc.appsync-realtime-api.eu-central-1.amazonaws.com/event/realtime"))
        #expect(fromHTTP.httpHost == "abc.appsync-api.eu-central-1.amazonaws.com")

        let custom = try #require(AppSyncEndpoints(endpoint: URL(string: "https://events.iskra.red/event")!))
        #expect(custom.httpHost == "events.iskra.red")
        #expect(custom.socketURL == URL(string: "wss://events.iskra.red/event/realtime"))
    }

    /// 401 is the expired-session path; any other 4xx (the kill switch flipped connection auth to IAM-only) falls to
    /// catch-up with no popup; a 5xx or a transport error is transient and worth the controller's backoff.
    @Test func aRefusedUpgradeMapsByItsStatus() async {
        let refusals: [(any Error, RealtimeTransportError)] = [
            (EventsSocketFailure.handshakeRefused(status: 401), .unauthorized),
            (EventsSocketFailure.handshakeRefused(status: 403), .unavailable),
            (EventsSocketFailure.handshakeRefused(status: 503), .connectionLost),
            (URLError(.networkConnectionLost), .connectionLost)
        ]
        for (failure, expected) in refusals {
            let harness = AppSyncTransportHarness()
            harness.socket.openFailure = failure
            await #expect(throws: expected) { try await harness.transport.connect(endpoint: harness.endpoint) }
            #expect(harness.socket.closeCount == 1, "the socket the refusal opened is closed")
        }
    }

    @Test func anAckThatNeverComesGivesTheConnectionUp() async {
        let harness = AppSyncTransportHarness()
        let task = Task { try await harness.transport.connect(endpoint: harness.endpoint) }
        await settle(until: { harness.sleep.held.count == 1 })

        harness.sleep.release()

        await #expect(throws: RealtimeTransportError.connectionLost) { try await task.value }
        #expect(harness.logger.messages(in: .chat, at: .warning).mentioning("ack timed out").count == 1)
    }

    @Test func aCancelledConnectThrowsPromptlyAndClosesWhatItOpened() async {
        let harness = AppSyncTransportHarness()
        let task = Task { try await harness.transport.connect(endpoint: harness.endpoint) }
        await settle(until: { harness.socket.sentTypes.contains("connection_init") })

        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(harness.socket.closeCount == 1)
    }

    /// The controller's `close()` calls `disconnect()` while a connect is still parked on its ack.
    @Test func disconnectDuringAnInFlightConnectMakesItThrow() async {
        let harness = AppSyncTransportHarness()
        let task = Task { try await harness.transport.connect(endpoint: harness.endpoint) }
        await settle(until: { harness.socket.sentTypes.contains("connection_init") })

        await harness.transport.disconnect()

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(harness.socket.closeCount == 1, "the socket the handshake opened is closed")
    }

    @Test func aMissingTokenMeansCatchUpOnly() async {
        let harness = AppSyncTransportHarness()
        harness.tokens.token = nil

        await #expect(throws: RealtimeTransportError.unavailable) {
            try await harness.transport.connect(endpoint: harness.endpoint)
        }
        #expect(harness.socket.openRequests.isEmpty, "no socket is opened without a token")
    }

    @Test func disconnectEndsEveryStreamAndClosesTheSocket() async throws {
        let harness = AppSyncTransportHarness()
        try await harness.connect()
        let (reader, _) = await harness.subscribe(to: .room(groupID: "g1", epoch: 1))

        await harness.transport.disconnect()

        await settle(until: { reader.hasEnded })
        #expect(reader.outcome == .some(nil), "the stream ends without an error")
        #expect(harness.socket.closeCount == 1)
        await harness.transport.disconnect()
        #expect(harness.socket.closeCount == 1, "a second disconnect is safe and has nothing left to close")
    }

    @Test func aDroppedConnectionFailsEveryStreamForTheControllerToReconnect() async throws {
        let harness = AppSyncTransportHarness()
        try await harness.connect()
        let (reader, _) = await harness.subscribe(to: .room(groupID: "g1", epoch: 1))

        harness.socket.fail(URLError(.networkConnectionLost))

        await settle(until: { reader.hasEnded })
        #expect(reader.outcome == .some(.connectionLost))
        #expect(harness.socket.closeCount == 1)
    }

    /// The protocol's rule: a client that saw no frame within the ack's window closes the connection itself.
    @Test func aMissedKeepAliveEndsTheConnection() async throws {
        let harness = AppSyncTransportHarness()
        try await harness.connect()
        let (reader, _) = await harness.subscribe(to: .room(groupID: "g1", epoch: 1))
        await settle(until: { harness.sleep.held.count == 1 })
        #expect(harness.sleep.held.map(\.seconds) == [300])

        harness.sleep.release()

        await settle(until: { reader.hasEnded })
        #expect(reader.outcome == .some(.connectionLost))
        #expect(harness.logger.messages(in: .chat, at: .warning).mentioning("keep-alive").count == 1)
    }
}
