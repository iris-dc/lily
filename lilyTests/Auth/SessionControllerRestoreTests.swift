import Foundation
import Testing
@testable import lily

/// Restore over what the store may hold after an interrupted sign-out.
@MainActor
struct SessionControllerRestoreTests {
    /// A sign-out the pool never confirmed leaves `.signingOut` in the store; the controller lands on the landing,
    /// never in guest mode and never signed in.
    @Test func aPendingSignOutMarkerRestoresToSignedOut() async {
        let harness = SessionHarness()
        harness.auth.restoreResult = .success(nil)
        harness.store.stored = .signingOut

        await harness.controller.restore()

        #expect(harness.controller.state == .signedOut)
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("No stored session") })
    }

    /// The service, not the controller, decides what the marker means: a session it restores stands.
    @Test func aPendingSignOutMarkerNeverOutranksARestoredSession() async {
        let harness = SessionHarness()
        harness.auth.restoreResult = .success(TestFixtures.session)
        harness.store.stored = .signingOut

        await harness.controller.restore()

        #expect(harness.controller.state == .signedIn(TestFixtures.user))
    }
}
