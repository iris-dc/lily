import SwiftUI
import Testing
@testable import lily

/// The width a transcript may use: its frame minus the part of it the window's safe-area insets actually cover.
struct UsableWidthTests {
    /// The iPad mini's detail column beside the floating sidebar: the frame starts where the inset region ends, so none
    /// of it is covered.
    @Test func aViewBesideTheInsetRegionKeepsItsWholeWidth() {
        let frame = CGRect(x: 310, y: 0, width: 434, height: 1000)
        #expect(UsableWidth.of(leading: 310, trailing: 0, frameInWindow: frame, windowWidth: 744) == 434)
    }

    /// A scroll view running under a floating sidebar: the covered part comes off.
    @Test func aViewUnderTheInsetRegionLosesTheCoveredPart() {
        let frame = CGRect(x: 0, y: 0, width: 1032, height: 1376)
        #expect(UsableWidth.of(leading: 360, trailing: 0, frameInWindow: frame, windowWidth: 1032) == 672)
    }

    @Test func aTrailingInsetIsJudgedTheSameWay() {
        let under = CGRect(x: 0, y: 0, width: 800, height: 600)
        #expect(UsableWidth.of(leading: 0, trailing: 200, frameInWindow: under, windowWidth: 800) == 600)
        let beside = CGRect(x: 0, y: 0, width: 600, height: 600)
        #expect(UsableWidth.of(leading: 0, trailing: 200, frameInWindow: beside, windowWidth: 800) == 600)
    }

    /// A frame that starts under the inset region and ends beside it loses only the covered part, never the whole inset.
    @Test func aPartialOverlapSubtractsOnlyTheOverlap() {
        let frame = CGRect(x: 100, y: 0, width: 600, height: 600)
        #expect(UsableWidth.of(leading: 310, trailing: 0, frameInWindow: frame, windowWidth: 800) == 390)
        #expect(UsableWidth.of(leading: 0, trailing: 200, frameInWindow: frame, windowWidth: 800) == 500)
        #expect(UsableWidth.of(leading: 310, trailing: 200, frameInWindow: frame, windowWidth: 800) == 290)
    }

    @Test func aPhoneWithoutHorizontalInsetsIsUnchanged() {
        let frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        #expect(UsableWidth.of(leading: 0, trailing: 0, frameInWindow: frame, windowWidth: 402) == 402)
    }

    /// Without the window's width the trailing inset is taken to overlap the view; the leading one is still judged
    /// from the frame.
    @Test func withoutTheWindowWidthOnlyTheTrailingInsetComesOffDirectly() {
        let beside = CGRect(x: 310, y: 0, width: 434, height: 1000)
        #expect(UsableWidth.of(leading: 310, trailing: 0, frameInWindow: beside, windowWidth: nil) == 434)
        let under = CGRect(x: 0, y: 0, width: 800, height: 600)
        #expect(UsableWidth.of(leading: 0, trailing: 200, frameInWindow: under, windowWidth: nil) == 600)
    }

    @Test func insetsLargerThanTheViewNeverGoNegative() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(UsableWidth.of(leading: 300, trailing: 300, frameInWindow: frame, windowWidth: 100) == 0)
    }
}
