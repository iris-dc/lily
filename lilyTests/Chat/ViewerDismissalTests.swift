import CoreGraphics
import Foundation
import Testing
@testable import lily

/// The viewer's drag to close: only up or down, far or thrown enough.
struct ViewerDismissalTests {
    private typealias Rules = ViewerDismissal
    private let far = DesignTokens.Layout.viewerDismissDistance

    @Test func onlyADragMoreUpOrDownThanSidewaysIsTheViewers() {
        #expect(Rules.beginsDismissal(velocity: CGSize(width: 40, height: 300)))
        #expect(Rules.beginsDismissal(velocity: CGSize(width: -40, height: -300)), "up counts as much as down")
        #expect(!Rules.beginsDismissal(velocity: CGSize(width: 300, height: 40)), "sideways is the pager's")
        #expect(!Rules.beginsDismissal(velocity: CGSize(width: 200, height: -200)), "a true diagonal is the pager's")
    }

    /// Far enough, or a throw that carries it far enough, closes; a slow short drag, or a throw back toward the middle,
    /// does not.
    @Test func lettingGoClosesWhenDraggedOrThrownFarEnough() {
        #expect(Rules.closes(drag: far, velocity: 0))
        #expect(Rules.closes(drag: -far, velocity: 0), "up closes as down does")
        #expect(Rules.closes(drag: -30, velocity: -1_000))
        #expect(!Rules.closes(drag: 60, velocity: 100))
        #expect(!Rules.closes(drag: 160, velocity: -800))
    }
}
