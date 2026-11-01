import Foundation
import Testing
@testable import lily

/// A refresh token the pool refuses mid-session ends the session like a sign-out and says why, once.
@MainActor
struct SessionControllerExpiryTests {
    @Test func anExpiredSessionEndsLikeASignOutAndSaysWhy() async {
        let harness = SessionHarness()
        harness.store.stored = .signedIn(TestFixtures.session)
        let controller = harness.makeController()
        let observer = SpySessionObserver()
        controller.addObserver(observer)
        var stateWhenWarned: SessionState?
        observer.onSessionWillEnd = { stateWhenWarned = controller.state }

        await controller.endExpiredSession()

        #expect(controller.state == .signedOut)
        #expect(harness.store.stored == nil)
        #expect(observer.willEndCount == 1 && observer.endCount == 1)
        #expect(stateWhenWarned == .signedIn(TestFixtures.user))
        #expect(harness.auth.signOutCount == 1)
        #expect(harness.errorCenter.current?.error == .sessionExpired)
        #expect(harness.logger.count(in: .auth, at: .warning, mentioning: TestFixtures.user.id, "expired") == 1)
    }

    @Test(arguments: [StoredSession?.none, .guest])
    func anExpiryWithNobodySignedInDoesNothing(stored: StoredSession?) async {
        let harness = SessionHarness()
        harness.store.stored = stored
        let controller = harness.makeController()
        let observer = SpySessionObserver()
        controller.addObserver(observer)

        await controller.endExpiredSession()

        #expect(harness.errorCenter.current == nil)
        #expect(observer.willEndCount == 0 && observer.endCount == 0)
        #expect(harness.auth.signOutCount == 0)
        #expect(harness.logger.hasLine(in: .auth, at: .debug, mentioning: "nobody signed in"))
    }

    /// The user's own sign-out is already warning its observers: the report is turned away, and no popup blames an
    /// expiry for a sign-out the user chose.
    @Test func anExpiryWhileASignOutRunsIsTurnedAway() async {
        let harness = SessionHarness()
        harness.store.stored = .signedIn(TestFixtures.session)
        let controller = harness.makeController()
        let observer = SpySessionObserver()
        observer.holdsWillEnd = true
        controller.addObserver(observer)
        let signOut = Task { await controller.signOut() }
        await settle(until: { observer.willEndCount == 1 })

        await controller.endExpiredSession()
        observer.releaseWillEnd()
        await signOut.value

        #expect(harness.errorCenter.current == nil)
        #expect(harness.logger.hasLine(in: .auth, at: .debug, mentioning: "another sign-out is in progress"))
        #expect(harness.auth.signOutCount == 1)
        #expect(observer.willEndCount == 1 && observer.endCount == 1)
    }

    /// A REST 401 put the popup up a moment earlier: one popup says it.
    @Test func anExpiryDoesNotRepeatAPopupAlreadyUp() async {
        let harness = SessionHarness()
        harness.store.stored = .signedIn(TestFixtures.session)
        let controller = harness.makeController()
        harness.errorCenter.report(AppError.sessionExpired)
        let shown = harness.errorCenter.current?.id

        await controller.endExpiredSession()

        #expect(controller.state == .signedOut)
        #expect(harness.errorCenter.current?.id == shown)
    }

    /// The revoke fails on a dead token, as it does after a manual sign-out; the session on the device is gone anyway.
    @Test func aFailedPoolSignOutAfterAnExpiryIsOnlyLogged() async {
        let harness = SessionHarness()
        harness.store.stored = .signedIn(TestFixtures.session)
        let controller = harness.makeController()
        harness.auth.signOutError = .network

        await controller.endExpiredSession()

        #expect(controller.state == .signedOut)
        #expect(harness.store.stored == nil)
        #expect(harness.errorCenter.current?.error == .sessionExpired)
        #expect(harness.logger.hasLine(in: .auth, at: .warning, mentioning: "Remote sign-out failed"))
    }
}
