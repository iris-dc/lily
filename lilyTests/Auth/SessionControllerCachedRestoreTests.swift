import Foundation
import Testing
@testable import lily

/// The first frame shows the cached session; the pool's answer settles it afterwards.
@MainActor
struct SessionControllerCachedRestoreTests {
    @Test(arguments: [
        (StoredSession?.none, SessionState.signedOut),
        (.guest, .guest),
        (.signingOut, .signedOut),
        (.signedIn(TestFixtures.session), .signedIn(TestFixtures.user)),
    ])
    func theStateStartsFromTheCache(stored: StoredSession?, expected: SessionState) {
        let harness = SessionHarness()
        harness.store.stored = stored

        #expect(harness.makeController().state == expected)
    }

    /// A cached user the pool no longer knows is signed out the way a sign-out is: observers told, store cleared.
    @Test func aPoolWithoutASessionEndsTheCachedOne() async {
        let harness = SessionHarness()
        harness.store.stored = .signedIn(TestFixtures.session)
        let controller = harness.makeController()
        let observer = SpySessionObserver()
        controller.addObserver(observer)
        var stateWhenWarned: SessionState?
        var stateWhenTold: SessionState?
        observer.onSessionWillEnd = { stateWhenWarned = controller.state }
        observer.onSessionEnd = { stateWhenTold = controller.state }
        harness.auth.restoreResult = .success(nil)
        #expect(controller.state == .signedIn(TestFixtures.user))

        await controller.restore()

        #expect(controller.state == .signedOut)
        #expect(harness.store.stored == nil)
        #expect(observer.willEndCount == 1 && observer.endCount == 1)
        #expect(stateWhenWarned == .signedIn(TestFixtures.user) && stateWhenTold == .signedOut)
        #expect(harness.auth.signOutCount == 0, "the service already signed the pool out where that was due")
        #expect(harness.logger.messages(in: .auth, at: .warning).contains { $0.contains("Cached session dropped") })
        #expect(harness.errorCenter.current == nil)
    }

    /// A check that could not be made (the pool unreachable) keeps the cached user; the backend's 401 decides later.
    @Test func aFailedCheckKeepsTheCachedUser() async {
        let harness = SessionHarness()
        harness.store.stored = .signedIn(TestFixtures.session)
        let controller = harness.makeController()
        let observer = SpySessionObserver()
        controller.addObserver(observer)
        harness.auth.restoreResult = .failure(.network)

        await controller.restore()

        #expect(controller.state == .signedIn(TestFixtures.user))
        #expect(observer.endCount == 0)
        #expect(harness.logger.messages(in: .auth, at: .info).contains { $0.contains("keeping it") })
    }

    /// A pool session the cache missed (the cache was cleared, the keychain kept the tokens) signs the user in.
    @Test func aPoolSessionWithoutACacheSignsIn() async {
        let harness = SessionHarness()
        harness.auth.restoreResult = .success(TestFixtures.session)
        #expect(harness.controller.state == .signedOut)

        await harness.controller.restore()

        #expect(harness.controller.state == .signedIn(TestFixtures.user))
        #expect(harness.logger.messages(in: .auth, at: .info).contains { $0.contains("Session restored") })
    }

    /// Observers hear of a restore that signed the user in the moment the state changes (the shell picks its tab before
    /// it is revealed), and of nothing else the check settles.
    @Test func aRestoreThatSignsInTellsTheObserversInTheSameTurn() async {
        let harness = SessionHarness()
        let observer = SpySessionObserver()
        harness.controller.addObserver(observer)
        var stateWhenTold: SessionState?
        observer.onSessionRestore = { stateWhenTold = harness.controller.state }
        harness.auth.restoreResult = .success(TestFixtures.session)

        await harness.controller.restore()

        #expect(observer.restoreCount == 1 && stateWhenTold == .signedIn(TestFixtures.user))

        let verified = SessionHarness()
        verified.store.stored = .signedIn(TestFixtures.session)
        let controller = verified.makeController()
        let quiet = SpySessionObserver()
        controller.addObserver(quiet)
        verified.auth.restoreResult = .success(TestFixtures.session)
        await controller.restore()
        #expect(quiet.restoreCount == 0)
    }

    /// A verified cache changes nothing and says so quietly.
    @Test func aVerifiedCacheIsLeftAlone() async {
        let harness = SessionHarness()
        harness.store.stored = .signedIn(TestFixtures.session)
        let controller = harness.makeController()
        harness.auth.restoreResult = .success(TestFixtures.session)

        await controller.restore()

        #expect(controller.state == .signedIn(TestFixtures.user))
        #expect(harness.logger.messages(in: .auth, at: .debug).contains { $0.contains("Session verified") })
        #expect(harness.logger.messages(in: .auth, at: .info).isEmpty)
    }

    /// The pool is asked once per process; a second restore, or a run joining it, waits for the same answer.
    @Test func theCheckRunsOnceAndLaterCallsJoinIt() async {
        let harness = SessionHarness()
        harness.auth.holdsRequests = true
        let controller = harness.controller
        let first = Task { await controller.restore() }
        let second = Task { await controller.restore() }
        await settle(until: { harness.auth.restoreCount == 1 })

        harness.auth.releaseRequests()
        await first.value
        await second.value
        await controller.restore()

        #expect(harness.auth.restoreCount == 1)
    }

    /// A sign-out while the check is out must not be undone by the check's answer.
    @Test func aSignOutDuringTheCheckStands() async {
        let harness = SessionHarness()
        harness.store.stored = .signedIn(TestFixtures.session)
        let controller = harness.makeController()
        harness.auth.restoreResult = .success(TestFixtures.session)
        harness.auth.holdsRequests = true
        let check = Task { await controller.restore() }
        await settle(until: { harness.auth.restoreCount == 1 })

        await controller.signOut()
        harness.auth.releaseRequests()
        await check.value

        #expect(controller.state == .signedOut)
        #expect(harness.logger.messages(in: .auth, at: .debug).contains { $0.contains("changed during the restore check") })
    }

    /// A sign-out tapped while the dropped session is still warning its observers is turned away: the session ends once,
    /// every observer hears it once, and the pool is not asked (it has no session to end).
    @Test func aSignOutWhileTheCachedSessionEndsIsTurnedAway() async {
        let harness = SessionHarness()
        harness.store.stored = .signedIn(TestFixtures.session)
        let controller = harness.makeController()
        let observer = SpySessionObserver()
        observer.holdsWillEnd = true
        controller.addObserver(observer)
        harness.auth.restoreResult = .success(nil)
        let check = Task { await controller.restore() }
        await settle(until: { observer.willEndCount == 1 })

        await controller.signOut()
        observer.releaseWillEnd()
        await check.value

        #expect(controller.state == .signedOut)
        #expect(observer.willEndCount == 1 && observer.endCount == 1)
        #expect(harness.auth.signOutCount == 0)
        #expect(harness.logger.messages(in: .auth, at: .debug).contains { $0.contains("another sign-out is in progress") })
    }
}
