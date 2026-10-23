import CoreGraphics
import Foundation
import Testing
@testable import lily

/// The viewer's drag to close: vertical closes, horizontal turns pages unless a single picture is shown, far or thrown
/// closes.
struct ViewerDismissalTests {
    private typealias Rules = ViewerDismissal

    @Test func theAxisIsReadOnceTheDragHasMovedFarEnough() {
        #expect(Rules.axis(of: CGSize(width: 3, height: 5)) == nil)
        #expect(Rules.axis(of: CGSize(width: 4, height: -30)) == .vertical, "up counts as much as down")
        #expect(Rules.axis(of: CGSize(width: -30, height: 10)) == .horizontal)
    }

    /// Sideways carries the page only for a single picture: a gallery's pager and a video's scrubber keep it.
    @Test func aHorizontalDragCarriesOnlyASinglePicture() {
        #expect(Rules.carriesHorizontally(pages: 1, isPicture: true))
        #expect(!Rules.carriesHorizontally(pages: 5, isPicture: true))
        #expect(!Rules.carriesHorizontally(pages: 1, isPicture: false))
    }

    /// The axis is read once: a drag that started vertical keeps carrying when it wanders sideways, and one that started
    /// sideways in a gallery never carries.
    @Test func theAxisReadFirstDecidesTheWholeDrag() {
        var vertical = Rules.Drag()
        vertical.follow(CGSize(width: 2, height: 20), carriesHorizontally: false)
        vertical.follow(CGSize(width: 60, height: 30), carriesHorizontally: false)
        #expect(vertical.axis == .vertical && vertical.carried == CGSize(width: 60, height: 30))
        var sideways = Rules.Drag()
        sideways.follow(CGSize(width: 20, height: 2), carriesHorizontally: false)
        sideways.follow(CGSize(width: 30, height: 80), carriesHorizontally: false)
        #expect(sideways.axis == .horizontal && sideways.carried == .zero)
        #expect(Rules.Drag.reading(CGSize(width: 0, height: 5), carriesHorizontally: true).carried == .zero, "too short")
    }

    @Test func theFadeFollowsTheDistanceUpToTheDismissDistance() {
        let far = DesignTokens.Layout.viewerDismissDistance
        #expect(Rules.progress(of: .zero) == 0)
        #expect(Rules.progress(of: CGSize(width: 0, height: far / 2)) == 0.5)
        #expect(Rules.progress(of: CGSize(width: far * 2, height: 0)) == 1)
    }

    @Test func lettingGoClosesWhenFarEnoughOrThrown() {
        let far = DesignTokens.Layout.viewerDismissDistance
        let thrown = DesignTokens.Layout.viewerThrowDistance
        #expect(Rules.closes(translation: CGSize(width: 0, height: far), predictedEnd: CGSize(width: 0, height: far)))
        #expect(Rules.closes(translation: CGSize(width: 0, height: -40), predictedEnd: CGSize(width: 0, height: -thrown)))
        #expect(!Rules.closes(translation: CGSize(width: 0, height: 40), predictedEnd: CGSize(width: 0, height: 120)))
    }
}
