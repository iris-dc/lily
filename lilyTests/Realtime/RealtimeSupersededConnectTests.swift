import Foundation
import Testing
@testable import lily

/// A `close()` that lands while the transport is still shaking hands: what becomes of the socket the handshake still
/// opens, and of the timers a failing one would arm.
@MainActor
struct RealtimeSupersededConnectTests {
    private let renewal = Duration.seconds(AppConfig.Realtime.maxConnectionAge)

    /// A suspend that lands while the transport is still shaking hands: the handshake completes anyway, and the socket
    /// it opened is closed at once, although the task that opened it is the cancelled one.
    @Test func aSuspendDuringTheHandshakeClosesTheSocketItStillOpened() async {
        let harness = RealtimeHarness()
        harness.transport.holdsConnects = true
        let first = Task { await harness.connect() }
        await settle(until: { harness.transport.isConnecting })

        await harness.controller.suspend()
        #expect(harness.transport.disconnectCount == 1, "the close itself")
        harness.transport.releaseConnects()
        await first.value

        #expect(harness.transport.connectCount == 1 && harness.transport.disconnectCount == 2)
        #expect(harness.controller.state == .disconnected)
    }

    /// A timer's reconnect supersedes a connect whose handshake then fails: that failure arms no backoff of its own,
    /// or its timer would later tear down the connection the reconnect opened.
    @Test func aFailingConnectSupersededByAReconnectArmsNoBackoff() async {
        let harness = RealtimeHarness()
        harness.transport.holdsConnects = true
        harness.transport.connectErrors = [RealtimeTransportError.connectionLost]
        let first = Task { await harness.connect() }
        await settle(until: { harness.transport.isConnecting })

        let reconnect = Task { await harness.controller.reconnect(reason: "test") }
        await settle(until: { harness.transport.disconnectCount == 1 })
        harness.transport.releaseConnects()
        await first.value
        await reconnect.value

        #expect(harness.transport.connectCount == 1, "the failed handshake is not counted; the reconnect's own is")
        #expect(harness.controller.state == .connected)
        #expect(harness.sleep.held == [renewal], "no backoff for the superseded attempt")
        #expect(harness.chatLogs(.debug).contains { $0.hasPrefix("Chat connection attempt superseded") })
    }
}
