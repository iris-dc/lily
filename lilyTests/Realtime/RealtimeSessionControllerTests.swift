import Foundation
import Testing
@testable import lily

/// Connection life: when it opens, how it renews, backs off, reports a refused token and closes.
@MainActor
struct RealtimeSessionControllerTests {
    private let user = TestFixtures.user
    private let userChannel = RealtimeChannel.user(sub: TestFixtures.user.id)
    private let renewal = Duration.seconds(AppConfig.Realtime.maxConnectionAge)

    @Test func connectsOnlyWhenActiveSignedInAndAnEndpointIsKnown() async {
        let harness = RealtimeHarness()

        await harness.controller.setDesired(active: false, user: user)
        await harness.controller.setDesired(active: true, user: nil)
        #expect(harness.transport.connectCount == 0 && harness.controller.state == .disconnected)

        harness.endpoint.url = nil
        await harness.connect()
        #expect(harness.controller.state == .unavailable && harness.transport.connectCount == 0)
        #expect(harness.chatLogs(.info).contains("Realtime disabled; catch-up only"))

        harness.endpoint.url = URL(string: "https://realtime.test/event")
        await harness.controller.resume()
        #expect(harness.controller.state == .connected && harness.transport.connectCount == 1)
        #expect(harness.transport.subscribedChannels == [userChannel])
        #expect(harness.chatLogs(.info).contains("Chat connection opened"))
        #expect(harness.groups.requestedScopes == [.mine], "the resume protocol reloads Mine once")
    }

    /// The token is sent by the transport; a signed-in user without one stays off the socket rather than 401-ing.
    @Test func aSignedInUserWithoutATokenStaysDisconnected() async {
        let harness = RealtimeHarness(tokens: FakeAuthTokenProvider(token: nil))
        await harness.connect()
        #expect(harness.transport.connectCount == 0 && harness.controller.state == .disconnected)
    }

    @Test func suspendClosesAndResumeReopensWithAFreshMineLoad() async {
        let harness = RealtimeHarness()
        await harness.connect()

        await harness.controller.suspend()
        #expect(harness.transport.disconnectCount == 1 && harness.controller.state == .disconnected)
        #expect(harness.chatLogs(.info).contains("Chat connection closed (background)"))
        await harness.yield()
        #expect(harness.transport.subscribedChannels.isEmpty)

        await harness.controller.resume()
        #expect(harness.transport.connectCount == 2 && harness.groups.requestedScopes.count == 2)
    }

    /// The shell's sync is cancelled when the scene phase changes again mid-disconnect; the socket must still close.
    @Test func aCancelledSuspendStillClosesTheConnection() async {
        let harness = RealtimeHarness()
        await harness.connect()
        harness.transport.holdsDisconnects = true

        let suspend = Task { await harness.controller.suspend() }
        await settle(until: { harness.transport.isDisconnecting })
        suspend.cancel()
        harness.transport.releaseDisconnects()
        await suspend.value

        #expect(harness.transport.disconnectCount == 1 && harness.controller.state == .disconnected)
    }

    /// A suspend while the first connect still waits for its token: that connect opens nothing and leaves the state
    /// disconnected, so the resume that follows finds a clean slate.
    @Test func aSuspendDuringTheTokenFetchLeavesTheNextResumeFree() async {
        let tokens = FakeAuthTokenProvider(token: "eyJ.token")
        tokens.holdsRequests = true
        let harness = RealtimeHarness(tokens: tokens)
        let first = Task { await harness.connect() }
        await settle(until: { tokens.isHolding })

        await harness.controller.suspend()
        tokens.releaseRequests()
        await first.value
        #expect(harness.controller.state == .disconnected && harness.transport.connectCount == 0)

        await harness.controller.resume()
        #expect(harness.controller.state == .connected && harness.transport.connectCount == 1)
        #expect(harness.transport.subscribedChannels == [userChannel])
    }

    /// The resume arrives while the connect that the suspend ended is still waiting for its token: it waits that one
    /// out and a connect follows, since the superseded one opens nothing.
    @Test func aResumeWaitingOnASupersededConnectStillConnects() async {
        let tokens = FakeAuthTokenProvider(token: "eyJ.token")
        tokens.holdsRequests = true
        let harness = RealtimeHarness(tokens: tokens)
        let first = Task { await harness.connect() }
        await settle(until: { tokens.isHolding })
        await harness.controller.suspend()

        let second = Task { await harness.controller.resume() }
        await harness.yield()
        #expect(tokens.requestCount == 1, "the resume waits for the connect in flight")
        tokens.releaseRequests()
        await first.value
        await second.value

        #expect(harness.controller.state == .connected && harness.transport.connectCount == 1)
        #expect(harness.transport.disconnectCount == 0, "the superseded connect opened nothing")
        #expect(harness.groups.requestedScopes == [.mine])
    }

    /// Two resumes at once (the shell's sync re-running while its first run still connects) share one connect.
    @Test func twoConcurrentResumesOpenOneConnection() async {
        let harness = RealtimeHarness()
        await harness.controller.setDesired(active: false, user: user)
        harness.endpoint.holdsRequests = true

        let first = Task { await harness.controller.resume() }
        let second = Task { await harness.controller.resume() }
        await settle(until: { harness.endpoint.isHolding })
        await harness.yield()
        #expect(harness.endpoint.requestCount == 1, "the second resume waits for the first connect")
        harness.endpoint.releaseRequests()
        await first.value
        await second.value

        #expect(harness.transport.connectCount == 1 && harness.controller.state == .connected)
        #expect(harness.groups.requestedScopes == [.mine])
    }

    @Test func expBoundRenewalReconnectsWithAForceRefreshedToken() async throws {
        let tokens = FakeAuthTokenProvider(token: JWTFixtures.token(expiringAt: Date(timeIntervalSince1970: 1_800_003_600)))
        tokens.freshTokens = [JWTFixtures.token(expiringAt: Date(timeIntervalSince1970: 1_800_010_800))]
        let harness = RealtimeHarness(tokens: tokens)

        await harness.connect()
        #expect(harness.sleep.held.map(\.seconds) == [3600 - AppConfig.Realtime.reconnectBeforeExpiry])

        harness.clock.advance(by: 3300)
        harness.sleep.release()
        await settle(until: { harness.sleep.held.count == 1 && harness.transport.connectCount == 2 })

        #expect(tokens.freshRequestCount == 1 && tokens.requestCount == 1)
        #expect(harness.transport.disconnectCount == 1)
        #expect(harness.sleep.held.map(\.seconds) == [10_800 - 3300 - AppConfig.Realtime.reconnectBeforeExpiry])
        #expect(harness.chatLogs(.info).contains("Chat connection closed (token renewal)"))
    }

    /// A refresh that hands back the same token would renew at once and loop; instead it waits out the backoff table.
    @Test func sameTokenTwiceBacksOff() async {
        let same = JWTFixtures.token(expiringAt: Date(timeIntervalSince1970: 1_800_003_600))
        let tokens = FakeAuthTokenProvider(token: same)
        tokens.freshTokens = [same, JWTFixtures.token(expiringAt: Date(timeIntervalSince1970: 1_800_010_800))]
        let harness = RealtimeHarness(tokens: tokens)
        await harness.connect()

        harness.clock.advance(by: 3300)
        harness.sleep.release()
        await settle(until: { harness.transport.connectCount == 2 && harness.sleep.held.count == 1 })
        let backoff = AppConfig.Realtime.reconnectBackoffSeconds[0] * (1 + AppConfig.Realtime.reconnectJitter)
        #expect(harness.sleep.held.map(\.seconds) == [backoff])
        #expect(harness.chatLogs(.warning).contains { $0.contains("expires no later than the last one") })

        // Wait for the connect to finish its resume protocol, so the renewal below is exercised against a settled
        // connection rather than superseding one mid-flight.
        await settle(until: { harness.controller.connectionTask == nil })
        harness.sleep.release()
        await settle(until: { harness.transport.connectCount == 3 && harness.sleep.held.count == 1 })
        #expect(harness.sleep.held.map(\.seconds) == [10_800 - 3300 - AppConfig.Realtime.reconnectBeforeExpiry])
    }

    /// A token already inside the renewal margin would renew at once and loop; it waits out the backoff table instead.
    @Test func aTokenInsideTheRenewalMarginRenewsWithBackoff() async {
        let soon = JWTFixtures.token(expiringAt: Date(timeIntervalSince1970: 1_800_000_060))
        let harness = RealtimeHarness(tokens: FakeAuthTokenProvider(token: soon))

        await harness.connect()

        let backoff = AppConfig.Realtime.reconnectBackoffSeconds[0] * (1 + AppConfig.Realtime.reconnectJitter)
        #expect(harness.sleep.held.map(\.seconds) == [backoff])
        #expect(harness.chatLogs(.warning).contains { $0.contains("inside the renewal margin") })
    }

    @Test func failedConnectsBackOffAlongTheTable() async {
        let harness = RealtimeHarness()
        harness.transport.connectErrors = [RealtimeTransportError.connectionLost, RealtimeTransportError.connectionLost]
        let table = AppConfig.Realtime.reconnectBackoffSeconds
        let jitter = 1 + AppConfig.Realtime.reconnectJitter

        await harness.connect()
        #expect(harness.controller.state == .disconnected && harness.sleep.held.map(\.seconds) == [table[0] * jitter])
        #expect(harness.chatLogs(.info).contains("Chat reconnecting in 1s (connect failed)"))

        harness.sleep.release()
        await settle(until: { harness.sleep.held.map(\.seconds) == [table[1] * jitter] })
        harness.sleep.release()
        await settle(until: { harness.controller.state == .connected && harness.sleep.held == [renewal] })
        #expect(harness.controller.backoffAttempt == 0, "a successful connect resets the backoff")
    }

    @Test func aLostConnectionReconnectsAfterABackoff() async {
        let harness = RealtimeHarness()
        await harness.connect()

        harness.transport.finish(userChannel, throwing: .connectionLost)
        let backoff = AppConfig.Realtime.reconnectBackoffSeconds[0] * (1 + AppConfig.Realtime.reconnectJitter)
        await settle(until: { harness.sleep.held.map(\.seconds) == [backoff] })
        #expect(harness.controller.state == .disconnected)
        #expect(harness.chatLogs(.info).contains("Chat connection closed (connection lost)"))

        harness.sleep.release()
        await settle(until: { harness.transport.connectCount == 2 })
        #expect(harness.controller.state == .connected && harness.transport.subscribedChannels == [userChannel])
    }

    @Test func aRefusedTokenReportsSessionExpiredOnceAndStopsReconnecting() async {
        let harness = RealtimeHarness(tokens: FakeAuthTokenProvider(token: "eyJ.token"))
        harness.transport.connectErrors = [RealtimeTransportError.unauthorized, RealtimeTransportError.unauthorized]

        await harness.connect()
        #expect(harness.errorCenter.current?.error == .sessionExpired && harness.controller.state == .disconnected)
        #expect(harness.sleep.held.isEmpty, "no reconnect is scheduled")

        await harness.controller.resume()
        #expect(harness.logger.messages(in: .ui).count == 1, "said once")
        #expect(!harness.logger.entries.contains { $0.message.contains("eyJ.token") })
    }

    @Test func signOutClosesTheConnectionAndForgetsTheRooms() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success([.fixture(id: "g1", role: .member)])
        await harness.connect()
        #expect(harness.controller.subscribedRooms == ["g1": 1])

        harness.controller.sessionDidEnd()
        await settle(until: { harness.transport.disconnectCount == 1 })

        #expect(harness.controller.subscribedRooms.isEmpty && harness.controller.state == .disconnected)
        await harness.controller.resume()
        #expect(harness.transport.connectCount == 1, "nobody is signed in")
    }

    @Test func aChangeOfUserStartsOver() async {
        let harness = RealtimeHarness()
        await harness.connect()

        await harness.controller.setDesired(active: true, user: AuthUser(id: "u-2", displayName: "Two", email: nil))

        #expect(harness.transport.disconnectCount == 1 && harness.transport.connectCount == 2)
        #expect(harness.transport.subscribedChannels == [.user(sub: "u-2")])
    }

    @Test func consumersLeaveNoContinuationBehind() async {
        let harness = RealtimeHarness()
        let stream = harness.controller.envelopes(for: "g1")
        let reader = Task { for await _ in stream {} }
        await settle(until: { harness.controller.consumers.count == 1 })

        reader.cancel()

        await settle(until: { harness.controller.consumers.isEmpty })
    }
}
