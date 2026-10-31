import Testing
import UIKit
@testable import lily

/// The launch's animation freeze: off from the delegate's call, on again the turn after the root appeared.
@MainActor
struct LaunchAnimationsTests {
    @Test func animationsAreOffUntilTheTurnAfterTheResume() async {
        LaunchAnimations.freeze()
        #expect(!UIView.areAnimationsEnabled)

        LaunchAnimations.resumeAfterFirstFrame()
        #expect(!UIView.areAnimationsEnabled, "the frame being built commits first")

        await settle(until: { UIView.areAnimationsEnabled })
        #expect(UIView.areAnimationsEnabled)
    }
}
