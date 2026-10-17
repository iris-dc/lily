import Foundation
import Testing
@testable import lily

/// `restore()` over an empty store, a guest choice, a check that could not be made and a sign-out marker. The cached
/// user's cases are in `SessionControllerCachedRestoreTests`.
@MainActor
struct SessionControllerRestoreTests {
    @Test func restoreWithNothingStoredSignsOut() async {
        let harness = SessionHarness()

        await harness.controller.restore()

        #expect(harness.controller.state == .signedOut)
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("No stored session") })
    }

    @Test func aGuestChoiceStandsWhenThePoolHasNoSession() async {
        let harness = SessionHarness()
        harness.store.stored = .guest
        let controller = harness.makeController()

        await controller.restore()

        #expect(controller.state == .guest)
        #expect(harness.store.stored == .guest)
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("Restored guest mode") })
    }

    /// A check that could not be made keeps the cached choice; a guest stays a guest, nothing is shown.
    @Test func restoreFailureKeepsTheCachedChoice() async {
        let harness = SessionHarness()
        harness.auth.restoreResult = .failure(.network)
        harness.store.stored = .guest
        let controller = harness.makeController()

        await controller.restore()

        #expect(controller.state == .guest)
        #expect(harness.errorCenter.current == nil)
    }

    @Test func restoreFailureWithNothingStoredSignsOut() async {
        let harness = SessionHarness()
        harness.auth.restoreResult = .failure(.network)

        await harness.controller.restore()

        #expect(harness.controller.state == .signedOut)
        #expect(harness.errorCenter.current == nil)
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("Could not verify") })
    }

    /// A sign-out the pool never confirmed leaves `.signingOut` in the store; the first frame is the landing, and the
    /// check (which finishes the sign-out at the pool) leaves it there.
    @Test func aPendingSignOutMarkerRestoresToSignedOut() async {
        let harness = SessionHarness()
        harness.auth.restoreResult = .success(nil)
        harness.store.stored = .signingOut
        let controller = harness.makeController()
        #expect(controller.state == .signedOut)

        await controller.restore()

        #expect(controller.state == .signedOut)
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("No stored session") })
    }

    /// The service, not the controller, decides what the marker means: a session it restores stands.
    @Test func aPendingSignOutMarkerNeverOutranksARestoredSession() async {
        let harness = SessionHarness()
        harness.auth.restoreResult = .success(TestFixtures.session)
        harness.store.stored = .signingOut
        let controller = harness.makeController()

        await controller.restore()

        #expect(controller.state == .signedIn(TestFixtures.user))
    }
}
