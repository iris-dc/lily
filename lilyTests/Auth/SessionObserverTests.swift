import Foundation
import Testing
@testable import lily

@MainActor
struct SessionObserverTests {
    /// Per-user state elsewhere in the app clears itself on this call, so it must come after the state has changed.
    @Test func signOutTellsObserversAfterTheStateChanged() async {
        let harness = SessionHarness()
        let observer = SpySessionObserver()
        var stateWhenTold: SessionState?
        observer.onSessionEnd = { stateWhenTold = harness.controller.state }
        harness.controller.addObserver(observer)
        await harness.controller.signIn(with: .apple)

        await harness.controller.signOut()

        #expect(observer.endCount == 1)
        #expect(stateWhenTold == .signedOut)
    }

    /// A device is unregistered while the Bearer still goes out, so the warning comes with the user still signed in.
    @Test func signOutTellsObserversBeforeTheStateChangesToo() async {
        let harness = SessionHarness()
        let observer = SpySessionObserver()
        var stateWhenWarned: SessionState?
        observer.onSessionWillEnd = { stateWhenWarned = harness.controller.state }
        harness.controller.addObserver(observer)
        await harness.controller.signIn(with: .apple)

        await harness.controller.signOut()

        #expect(observer.willEndCount == 1 && observer.endCount == 1)
        #expect(stateWhenWarned?.user != nil)
    }

    /// Registering must not keep an observer alive: stores come and go with their owners, the controller lives forever.
    @Test func observersAreHeldWeakly() async {
        let harness = SessionHarness()
        var observer: SpySessionObserver? = SpySessionObserver()
        weak let weakObserver = observer
        harness.controller.addObserver(observer!)

        observer = nil
        await harness.controller.signOut()

        #expect(weakObserver == nil)
    }
}
