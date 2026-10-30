import Foundation
import Testing
@testable import lily

/// The Explore loads a run makes alongside its chain (`ShellLists.loadExploreIfStale`), so the tab holds a fresh answer
/// before it is first opened; the chain itself is `ShellSyncTests`'.
@MainActor
struct ShellSyncExploreTests {
    private let realtime: RealtimeHarness
    private let push = PushHarness()
    private let session = SessionHarness()
    private let sync: ShellSync

    init() {
        let tokens = FakeAuthTokenProvider(token: JWTFixtures.token(expiringAt: Date(timeIntervalSince1970: 1_800_003_600)))
        let realtime = RealtimeHarness(tokens: tokens)
        self.realtime = realtime
        sync = ShellSync.make(session: session.controller, realtime: realtime, push: push)
    }

    /// After the session check like everything else, and alongside the chain rather than at its end.
    @Test func exploreLoadsOnceTheSessionCheckAnswered() async {
        session.auth.restoreResult = .success(TestFixtures.session)
        session.auth.holdsRequests = true
        let sync = sync
        let run = Task { await sync.run(active: true, user: TestFixtures.user) }
        await settle(until: { session.auth.restoreCount == 1 })
        #expect(realtime.events.requestedScopes.isEmpty)

        session.auth.releaseRequests()
        await run.value

        #expect(realtime.events.requestedScopes.contains(.upcoming) && !realtime.events.requestedScopes.contains(.joined))
        #expect(realtime.tournaments.requestedScopes.contains(.upcoming) == AppConfig.FeatureFlags.tournaments)
    }

    @Test func exploreLoadsWhileTheAccountIsStillOut() async {
        session.auth.restoreResult = .success(TestFixtures.session)
        realtime.meRepository.holdsRequests = true
        let sync = sync
        let run = Task { await sync.run(active: true, user: TestFixtures.user) }
        await settle(until: { realtime.meRepository.meCallCount == 1 && realtime.events.requestedScopes.contains(.upcoming) })

        realtime.meRepository.releaseRequests()
        await run.value
    }

    /// Explore is for guests too: a guest's run loads it while asking for nothing user-scoped.
    @Test func aGuestRunLoadsExplore() async {
        session.controller.continueAsGuest()
        realtime.identity.currentUserID = nil
        push.identity.currentUserID = nil

        await sync.run(active: true, user: nil)

        // Once without the position and once with it, as the tab's own appearance does; never Home's scope.
        #expect(realtime.events.requestedScopes.contains(.upcoming) && !realtime.events.requestedScopes.contains(.joined))
    }

    /// A signed-out visitor is on the landing: nothing is asked for them, and no position either (its permission alert
    /// would land over the intro).
    @Test func aSignedOutRunLoadsNothing() async {
        realtime.identity.currentUserID = nil
        push.identity.currentUserID = nil

        await sync.run(active: true, user: nil)

        #expect(session.controller.state == .signedOut)
        #expect(realtime.events.requestedScopes.isEmpty && realtime.tournaments.requestedScopes.isEmpty)
        #expect(realtime.groups.requestedScopes.isEmpty)
    }

    @Test func aBackgroundRunLoadsNothing() async {
        await sync.run(active: false, user: TestFixtures.user)

        #expect(realtime.events.requestedScopes.isEmpty && realtime.tournaments.requestedScopes.isEmpty)
    }
}
