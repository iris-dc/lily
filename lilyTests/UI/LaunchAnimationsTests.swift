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

    /// Should the root never appear, the fallback turns the animations on regardless.
    @Test func theFallbackResumesWithoutTheRoot() async throws {
        LaunchAnimations.freeze(resumingAfter: 0.05)
        #expect(!UIView.areAnimationsEnabled)

        for _ in 0..<50 where !UIView.areAnimationsEnabled {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(UIView.areAnimationsEnabled)
    }
}
