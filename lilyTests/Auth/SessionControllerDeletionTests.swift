import Foundation
import Testing
@testable import lily

/// The dedicated account-deleted session end and its stand-down for racing 401s (the deletion contract).
@MainActor
struct SessionControllerDeletionTests {
    /// Records the observer words in order; the dedicated word also reports what the controller still held, so the
    /// teardown order (last word while signed in, stores cleared after) is asserted, not assumed.
    @MainActor
    private final class SpySessionObserver: SessionObserver {
        private(set) var events: [String] = []
        var onWillEndWithoutNetwork: () -> Void = {}

        func sessionWillEnd() async {
            events.append("willEnd")
        }

        func sessionWillEndWithoutNetwork() async {
            events.append("willEndWithoutNetwork")
            onWillEndWithoutNetwork()
        }

        func sessionDidEnd() {
            events.append("didEnd")
        }
    }

    /// An observer from before the deletion contract: only the authenticated last word is written.
    @MainActor
    private final class LegacySessionObserver: SessionObserver {
        private(set) var events: [String] = []

        func sessionWillEnd() async {
            events.append("willEnd")
        }

        func sessionDidEnd() {
            events.append("didEnd")
        }
    }

    @Test func theDeletedEndSkipsTheAuthenticatedLastWordAndShowsNoPopup() async {
        let harness = SessionHarness()
        harness.store.stored = .signedIn(TestFixtures.session)
        await harness.controller.signIn(with: .apple)
        let observer = SpySessionObserver()
        harness.controller.addObserver(observer)
        var stateDuringLastWord: SessionState?
        observer.onWillEndWithoutNetwork = { [controller = harness.controller] in stateDuringLastWord = controller.state }

        await harness.controller.endDeletedSession()

        #expect(observer.events == ["willEndWithoutNetwork", "didEnd"], "never the authenticated last word")
        #expect(stateDuringLastWord == .signedIn(TestFixtures.user), "the last word runs while still signed in")
        #expect(harness.controller.state == .signedOut && harness.store.stored == nil)
        #expect(harness.auth.signOutCount == 1, "the pool sign-out still clears the local tokens")
        #expect(harness.errorCenter.current == nil, "no popup: the flow's acknowledgment was the word")
        #expect(harness.logger.messages(in: .auth)
            .contains { $0.contains("Account deleted for user") && $0.contains(TestFixtures.user.id) })
    }

    @Test func anObserverWithoutTheDedicatedWordKeepsItsLastWord() async {
        let harness = SessionHarness()
        await harness.controller.signIn(with: .apple)
        let observer = LegacySessionObserver()
        harness.controller.addObserver(observer)

        await harness.controller.endDeletedSession()

        #expect(observer.events == ["willEnd", "didEnd"], "the default forwards, so local-only cleanup still runs")
    }

    @Test func racing401sDuringTheDeleteFlowEndNothingAndRaiseNoPopup() async {
        let harness = SessionHarness()
        await harness.controller.signIn(with: .apple)
        harness.controller.beginAccountDeletion()

        await harness.controller.endExpiredSession()

        #expect(harness.controller.state == .signedIn(TestFixtures.user), "the locked sheet keeps its session")
        #expect(harness.errorCenter.current == nil)
        #expect(harness.auth.signOutCount == 0)
        #expect(harness.logger.messages(in: .auth, at: .debug).contains { $0.contains("during account deletion") })
    }

    @Test func backingOutOfTheFlowRestoresTheExpiredSessionEnd() async {
        let harness = SessionHarness()
        await harness.controller.signIn(with: .apple)
        harness.controller.beginAccountDeletion()
        harness.controller.cancelAccountDeletion()

        await harness.controller.endExpiredSession()

        #expect(harness.controller.state == .signedOut)
        #expect(harness.errorCenter.current?.error == .sessionExpired)
    }

    @Test func theDeletedEndLiftsTheStandDownForTheNextSession() async {
        let harness = SessionHarness()
        await harness.controller.signIn(with: .apple)
        harness.controller.beginAccountDeletion()
        await harness.controller.endDeletedSession()
        await harness.controller.signIn(with: .apple)

        await harness.controller.endExpiredSession()

        #expect(harness.controller.state == .signedOut)
        #expect(harness.errorCenter.current?.error == .sessionExpired)
    }

    @Test func theDeletedEndWithNobodySignedInDoesNothing() async {
        let harness = SessionHarness()
        let observer = SpySessionObserver()
        harness.controller.addObserver(observer)

        await harness.controller.endDeletedSession()

        #expect(observer.events.isEmpty && harness.auth.signOutCount == 0)
        #expect(harness.logger.messages(in: .auth, at: .debug)
            .contains { $0.contains("Account-deleted end with nobody signed in") })
    }
}
