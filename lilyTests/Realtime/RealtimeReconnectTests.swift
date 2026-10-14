import Foundation
import Testing
@testable import lily

/// Connection lifecycle cases the main suite, at its 200-line body limit, cannot hold: the bounded reconnect when a
/// forced token refresh answers nothing, a backoff timer made stale by a connect that landed meanwhile, every stream
/// ending at once or finishing cleanly, a Mine reload that fails or is interrupted by a suspend during the resume
/// protocol, the session state a changed user leaves behind, and the opened line naming the endpoint's host.
@MainActor
struct RealtimeReconnectTests {
    private let userChannel = RealtimeChannel.user(sub: TestFixtures.user.id)
    private let renewal = Duration.seconds(AppConfig.Realtime.maxConnectionAge)
    private let table = AppConfig.Realtime.reconnectBackoffSeconds
    private let jitter = 1 + AppConfig.Realtime.reconnectJitter

    /// The renewal's forced refresh answers nothing (a network still down, most often): the connection backs off along
    /// the table instead of staying dead until the next scene change, and the refresh that answers connects.
    @Test func aMissingTokenOnRenewalArmsABoundedReconnect() async {
        let tokens = FakeAuthTokenProvider(token: JWTFixtures.token(expiringAt: Date(timeIntervalSince1970: 1_800_003_600)))
        tokens.freshTokens = [nil, JWTFixtures.token(expiringAt: Date(timeIntervalSince1970: 1_800_010_800))]
        let harness = RealtimeHarness(tokens: tokens)
        await harness.connect()
        #expect(harness.sleep.held.map(\.seconds) == [3600 - AppConfig.Realtime.reconnectBeforeExpiry])

        harness.clock.advance(by: 3300)
        harness.sleep.release()
        await settle(until: { harness.sleep.held.map(\.seconds) == [table[0] * jitter] })
        #expect(harness.controller.state == .disconnected)
        #expect(harness.transport.connectCount == 1 && harness.transport.disconnectCount == 1)
        #expect(harness.chatLogs(.warning).contains("No access token for the realtime connection; staying disconnected"))
        #expect(harness.chatLogs(.info).contains("Chat reconnecting in 1s (no token)"))

        harness.sleep.release()
        await settle(until: { harness.transport.connectCount == 2 && harness.sleep.held.count == 1 })
        #expect(harness.controller.state == .connected && tokens.freshRequestCount == 2)
        #expect(harness.controller.reconnectsWithoutToken == 0, "a token obtained starts the budget over")
        #expect(harness.sleep.held.map(\.seconds) == [10_800 - 3300 - AppConfig.Realtime.reconnectBeforeExpiry],
                "the renewal for the new token")
    }

    /// A lost connection's reconnect refreshes the token; when that answers nothing, the next table entry is waited
    /// out rather than the connection given up on.
    @Test func aLostConnectionWhoseFreshTokenIsMissingBacksOffAgain() async {
        let tokens = FakeAuthTokenProvider(token: "eyJ.token")
        tokens.freshTokens = [nil, "eyJ.token"]
        let harness = RealtimeHarness(tokens: tokens)
        await harness.connect()

        harness.transport.finish(userChannel, throwing: .connectionLost)
        await settle(until: { harness.sleep.held.map(\.seconds) == [table[0] * jitter] })
        harness.sleep.release()
        await settle(until: { harness.sleep.held.map(\.seconds) == [table[1] * jitter] })
        #expect(harness.transport.connectCount == 1, "no token, no connect")
        #expect(harness.chatLogs(.info).contains("Chat reconnecting in 2s (no token)"))

        harness.sleep.release()
        await settle(until: { harness.transport.connectCount == 2 })
        #expect(harness.controller.state == .connected)
    }

    /// A tokenless answer to the lost connection's reconnect and to every backoff after it exhausts the budget at the
    /// bound: the connection waits for the next foreground, where the cached token is tried again.
    @Test func reconnectsWithoutATokenStopAtTheBound() async {
        let bound = AppConfig.Realtime.maxReconnectsWithoutToken
        let tokens = FakeAuthTokenProvider(token: "eyJ.token")
        tokens.freshTokens = Array(repeating: nil, count: bound + 1)
        let harness = RealtimeHarness(tokens: tokens)
        await harness.connect()

        harness.transport.finish(userChannel, throwing: .connectionLost)
        for _ in 0...bound {
            await settle(until: { harness.sleep.held.count == 1 && harness.sleep.held != [renewal] })
            harness.sleep.release()
        }
        await settle(until: {
            harness.chatLogs(.warning).contains("No access token after \(bound) reconnects; waiting for the next foreground")
        })
        #expect(harness.sleep.held.isEmpty && harness.controller.state == .disconnected)
        #expect(tokens.freshRequestCount == bound + 1 && harness.transport.connectCount == 1)

        await harness.controller.resume()
        #expect(harness.transport.connectCount == 2 && harness.controller.state == .connected,
                "the next foreground tries again with the cached token")
    }

    /// An `.active` <-> `.inactive` flip re-runs `resume()` while a backoff is pending: the connect that lands disarms
    /// the timer, which would otherwise tear the healthy socket down when it fired.
    @Test func aConnectThatLandsWhileABackoffIsPendingCancelsTheTimer() async {
        let harness = RealtimeHarness()
        harness.transport.connectErrors = [RealtimeTransportError.connectionLost]
        await harness.connect()
        #expect(harness.sleep.held.map(\.seconds) == [table[0] * jitter] && harness.controller.state == .disconnected)

        await harness.controller.resume()
        await settle(until: { harness.sleep.held == [renewal] })
        await harness.yield()
        #expect(harness.transport.disconnectCount == 0 && harness.transport.connectCount == 1)
        #expect(harness.controller.state == .connected && harness.controller.reconnectTask == nil)
    }

    /// The socket drops and every stream ends in the same turn: the first to notice closes the connection and arms the
    /// one backoff, the rest find their subscription gone, and the reconnect brings every room back.
    @Test func everyStreamEndingTogetherClosesOnceAndReconnectsOnce() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success(RealtimeHarness.mine(3))
        await harness.connect()
        let rooms = (1...3).map { RealtimeChannel.room(groupID: "g\($0)", epoch: 1) }
        #expect(Set(harness.transport.subscribedChannels) == Set([userChannel] + rooms))

        harness.transport.finish(userChannel, throwing: .connectionLost)
        rooms.forEach { harness.transport.finish($0, throwing: .connectionLost) }
        await settle(until: { harness.sleep.held.map(\.seconds) == [table[0] * jitter] })
        #expect(harness.transport.disconnectCount == 1 && harness.controller.state == .disconnected)
        #expect(harness.chatLogs(.info).filter { $0 == "Chat connection closed (connection lost)" }.count == 1)
        #expect(harness.chatLogs(.info).filter { $0.hasPrefix("Chat reconnecting in") }.count == 1)
        #expect(harness.chatLogs(.warning).filter { $0.hasPrefix("Stream ended on") }.count == 1, "the first ender alone logs")

        harness.sleep.release()
        await settle(until: { harness.transport.connectCount == 2 && harness.groups.requestedScopes.count == 2 })
        await harness.yield()
        #expect(harness.controller.state == .connected)
        #expect(Set(harness.transport.subscribedChannels) == Set([userChannel] + rooms))
        #expect(harness.controller.subscribedRooms == ["g1": 1, "g2": 1, "g3": 1])
    }

    /// A stream the library finishes without an error is still one the controller did not end: the connection is gone
    /// and comes back through the backoff like any lost one.
    @Test func aStreamFinishingCleanlyIsALostConnection() async {
        let harness = RealtimeHarness()
        await harness.connect()

        harness.transport.finish(userChannel, throwing: nil)
        await settle(until: { harness.sleep.held.map(\.seconds) == [table[0] * jitter] })
        #expect(harness.controller.state == .disconnected && harness.transport.disconnectCount == 1)
        #expect(harness.chatLogs(.warning).contains("Stream ended on \(userChannel.path): finished"))
        #expect(harness.chatLogs(.info).contains("Chat connection closed (connection lost)"))
        #expect(harness.chatLogs(.info).contains("Chat reconnecting in 1s (connection lost)"))
    }

    /// Mine failing to reload on a resume is the store's problem and the store's report: the rooms it still holds are
    /// subscribed and the open room is caught up as if the reload had answered.
    @Test func aFailedMineReloadStillSyncsTheRoomsItHolds() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success(RealtimeHarness.mine(1))
        await harness.connect()
        harness.cache.store(.fixture(groupID: "g1", messages: [.fixture(id: "m1", groupID: "g1")]), for: "g1")
        harness.controller.setOpenRoom(RoomSubscription(groupID: "g1", epoch: 1))
        harness.groups.result = .failure(.network)

        await harness.controller.suspend()
        await harness.controller.resume()
        #expect(harness.controller.state == .connected && harness.controller.subscribedRooms == ["g1": 1])
        #expect(harness.transport.subscribedChannels.contains(.room(groupID: "g1", epoch: 1)))
        #expect(harness.chat.newerRequests.map { $0.groupID } == ["g1"],
                "the open room is caught up although Mine did not reload")
        #expect(harness.store.groups.map(\.id) == ["g1"])
        #expect(harness.errorCenter.current?.error == .network, "the store's own report")
    }

    /// A suspend that lands while the resume protocol waits for Mine ends the connection and every catch-up with it:
    /// nobody is there to show a page, so none is fetched; the Mine load, a flight of its own, still lands.
    @Test func aSuspendDuringTheResumeProtocolStopsTheCatchUps() async {
        let harness = RealtimeHarness()
        harness.groups.result = .success(RealtimeHarness.mine(1))
        await harness.connect()
        harness.cache.store(.fixture(groupID: "g1", messages: [.fixture(id: "m1", groupID: "g1")]), for: "g1")
        harness.controller.setOpenRoom(RoomSubscription(groupID: "g1", epoch: 1))
        await harness.controller.suspend()

        harness.groups.holdsRequests = true
        let resume = Task { await harness.controller.resume() }
        await settle(until: { harness.store.isLoading })
        await harness.controller.suspend()
        harness.groups.releaseRequests()
        await resume.value
        #expect(harness.chat.newerRequests.isEmpty && harness.controller.subscribedRooms.isEmpty)
        #expect(harness.controller.state == .disconnected && harness.transport.disconnectCount == 2)
        #expect(harness.store.groups.map(\.id) == ["g1"], "the SingleFlight load still landed")
    }

    /// The epochs noted, the expiry the renewal compares against, the backoff position and the "session expired" said
    /// once are the signed-in user's: another user signing in starts every one over, so their refused token is reported
    /// again. The epoch is noted while the connection is down, the way an open chat notes it.
    @Test func aChangedUserForgetsTheExpiredSessionFlagAndTheEpochs() async {
        let tokens = FakeAuthTokenProvider(token: JWTFixtures.token(expiringAt: Date(timeIntervalSince1970: 1_800_003_600)))
        let harness = RealtimeHarness(tokens: tokens)
        await harness.connect()
        harness.transport.finish(userChannel, throwing: .connectionLost)
        await settle(until: { harness.sleep.held.map(\.seconds) == [table[0] * jitter] })
        harness.controller.setOpenRoom(RoomSubscription(groupID: "g1", epoch: 3))
        harness.transport.connectErrors = [RealtimeTransportError.unauthorized]
        harness.sleep.release()
        await settle(until: { harness.errorCenter.current?.error == .sessionExpired })
        #expect(harness.controller.reportedExpiredSession && harness.controller.backoff.attempt == 1)
        #expect(harness.controller.knownEpochs["g1"] == 3 && harness.controller.lastExpiry != nil)

        harness.errorCenter.dismiss()
        harness.transport.connectErrors = [RealtimeTransportError.unauthorized]
        await harness.controller.setDesired(active: true, user: AuthUser(id: "u-2", displayName: "Two", email: nil))
        #expect(harness.errorCenter.current?.error == .sessionExpired, "the new user's refused token is reported again")
        #expect(harness.controller.knownEpochs["g1"] == nil)
        #expect(harness.controller.lastExpiry == nil, "the renewal compares the next token against nothing")
        #expect(harness.controller.backoff.attempt == 0 && harness.controller.reconnectsWithoutToken == 0)
        #expect(harness.sleep.held.isEmpty)
    }

    /// The tokenless-reconnect budget is the signed-in user's too: another user signing in while a "no token" backoff is
    /// pending drops the timer and starts the count over, and their own first connect without a token arms nothing.
    @Test func aChangedUserStartsTheTokenlessReconnectBudgetOver() async {
        let tokens = FakeAuthTokenProvider(token: "eyJ.token")
        tokens.freshTokens = [nil]
        let harness = RealtimeHarness(tokens: tokens)
        await harness.connect()
        harness.transport.finish(userChannel, throwing: .connectionLost)
        await settle(until: { harness.sleep.held.map(\.seconds) == [table[0] * jitter] })
        harness.sleep.release()
        await settle(until: { harness.sleep.held.map(\.seconds) == [table[1] * jitter] })
        #expect(harness.controller.reconnectsWithoutToken == 1)

        tokens.token = nil
        await harness.controller.setDesired(active: true, user: AuthUser(id: "u-2", displayName: "Two", email: nil))
        await settle(until: { harness.sleep.held.isEmpty })
        #expect(harness.controller.reconnectsWithoutToken == 0 && harness.controller.state == .disconnected)
        #expect(harness.transport.connectCount == 1, "no token, no connect for the new user either")
    }

    /// The opened line names the endpoint's host (ours, never user data), so a log shows which endpoint a build reached.
    @Test func theConnectionOpenedLineNamesTheHost() async throws {
        let harness = RealtimeHarness()
        await harness.connect()

        let host = try #require(harness.endpoint.url?.host())
        #expect(harness.chatLogs(.info).filter { $0 == "Chat connection opened to \(host)" }.count == 1)
    }
}
