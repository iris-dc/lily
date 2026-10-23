import SwiftUI
import Testing
@testable import lily

/// The viewer's drag to close: only up or down, far or thrown enough, carrying on from the speed it was let go with.
struct ViewerDismissalTests {
    private typealias Rules = ViewerDismissal
    private let far = DesignTokens.Layout.viewerDismissDistance

    @Test func onlyADragMoreUpOrDownThanSidewaysIsTheViewers() {
        #expect(Rules.beginsDismissal(velocity: CGSize(width: 40, height: 300)))
        #expect(Rules.beginsDismissal(velocity: CGSize(width: -40, height: -300)), "up counts as much as down")
        #expect(!Rules.beginsDismissal(velocity: CGSize(width: 300, height: 40)), "sideways is the pager's")
        #expect(!Rules.beginsDismissal(velocity: CGSize(width: 200, height: -200)), "a true diagonal is the pager's")
    }

    @Test func theFadeFollowsTheDistanceUpOrDownOnly() {
        #expect(Rules.progress(of: .zero) == 0)
        #expect(Rules.progress(of: CGSize(width: 0, height: -far / 2)) == 0.5)
        #expect(Rules.progress(of: CGSize(width: 300, height: 0)) == 0, "sideways does not fade it")
        #expect(Rules.progress(of: CGSize(width: 0, height: far * 2)) == 1)
    }

    /// Far enough, or a throw that carries it far enough, closes; a slow short drag, or a throw back toward the middle,
    /// does not.
    @Test func lettingGoClosesWhenDraggedOrThrownFarEnough() {
        #expect(Rules.closes(translation: CGSize(width: 0, height: far), velocity: .zero))
        #expect(Rules.closes(translation: CGSize(width: 0, height: -30), velocity: CGSize(width: 0, height: -1_000)))
        #expect(!Rules.closes(translation: CGSize(width: 0, height: 60), velocity: CGSize(width: 0, height: 100)))
        #expect(!Rules.closes(translation: CGSize(width: 0, height: 160), velocity: CGSize(width: 0, height: -800)))
    }

    @Test func theClosingPageFliesOffTheWayItWasThrown() {
        #expect(Rules.flyOut(from: CGSize(width: 12, height: 150), velocity: .zero, height: 874)
                == CGSize(width: 12, height: 874))
        #expect(Rules.flyOut(from: CGSize(width: 0, height: 20), velocity: CGSize(width: 0, height: -1_500), height: 874)
                == CGSize(width: 0, height: -874), "a throw up after a short drag down goes up")
        #expect(Rules.flyOut(from: CGSize(width: 0, height: -150), velocity: .zero, height: 874)
                == CGSize(width: 0, height: -874), "a page let go at rest above the middle goes up")
        #expect(Rules.flyOut(from: .zero, velocity: .zero, height: 874) == CGSize(width: 0, height: 874))
    }

    /// The fly-off starts at the finger's speed: a throw slows evenly over the rest of the way (a start at twice its
    /// average), a slow release takes the longest bound and starts gentler, a page let go at rest or moving back starts
    /// from rest, and the quickest throw is held to the shortest bound and a start that does not overshoot.
    @Test func theFlyOutStartsAtTheSpeedItWasLetGoWith() {
        let bounds = DesignTokens.Duration.viewerFlyOutDuration
        let from = CGSize(width: 0, height: 200)
        let away = CGSize(width: 0, height: 874)
        let thrown = Rules.flyOutMotion(from: from, to: away, velocity: CGSize(width: 0, height: 6_000))
        #expect(abs(thrown.duration - 0.2247) < 0.001)
        #expect(abs(thrown.startSlope - 2) < 0.001, "an even slowing")
        let slow = Rules.flyOutMotion(from: from, to: away, velocity: CGSize(width: 0, height: 1_000))
        #expect(slow.duration == bounds.upperBound)
        #expect(abs(slow.startSlope * 674 / slow.duration - 1_000) < 1, "it starts at the finger's 1,000 pt/s")
        #expect(abs(slow.curve.velocity(at: 0) - slow.startSlope) < 0.001, "the curve starts at that slope")
        let still = FlyOutMotion(duration: bounds.upperBound, startSlope: 0)
        #expect(Rules.flyOutMotion(from: from, to: away, velocity: .zero) == still)
        #expect(Rules.flyOutMotion(from: from, to: away, velocity: CGSize(width: 0, height: -100)) == still,
                "a finger moving back counts as at rest")
        let flung = Rules.flyOutMotion(from: from, to: away, velocity: CGSize(width: 0, height: 50_000))
        #expect(flung == FlyOutMotion(duration: bounds.lowerBound, startSlope: FlyOutMotion.steepestStart))
        #expect(stride(from: 0, through: 1, by: 0.05).allSatisfy { flung.curve.value(at: $0) <= 1.000_1 },
                "the steepest start never overshoots")
    }
}
