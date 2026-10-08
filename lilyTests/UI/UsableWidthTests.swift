import SwiftUI
import Testing
@testable import lily

/// The width a transcript may use: its frame minus the part of it the window's safe-area insets actually cover.
struct UsableWidthTests {
    /// The iPad mini's detail column beside the floating sidebar (seen 2026-10-08: width 434 at x 310 with a leading
    /// inset of 310): the frame starts where the inset region ends, so none of it is covered.
    @Test func aViewBesideTheInsetRegionKeepsItsWholeWidth() {
        let frame = CGRect(x: 310, y: 0, width: 434, height: 1000)
        #expect(UsableWidth.of(width: 434, leading: 310, trailing: 0, frameInWindow: frame, windowWidth: 744) == 434)
    }

    /// A scroll view running under a floating sidebar: the covered part comes off.
    @Test func aViewUnderTheInsetRegionLosesTheCoveredPart() {
        let frame = CGRect(x: 0, y: 0, width: 1032, height: 1376)
        #expect(UsableWidth.of(width: 1032, leading: 360, trailing: 0, frameInWindow: frame, windowWidth: 1032) == 672)
    }

    @Test func aTrailingInsetIsJudgedTheSameWay() {
        let under = CGRect(x: 0, y: 0, width: 800, height: 600)
        #expect(UsableWidth.of(width: 800, leading: 0, trailing: 200, frameInWindow: under, windowWidth: 800) == 600)
        let beside = CGRect(x: 0, y: 0, width: 600, height: 600)
        #expect(UsableWidth.of(width: 600, leading: 0, trailing: 200, frameInWindow: beside, windowWidth: 800) == 600)
    }

    @Test func aPhoneWithoutHorizontalInsetsIsUnchanged() {
        let frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        #expect(UsableWidth.of(width: 402, leading: 0, trailing: 0, frameInWindow: frame, windowWidth: 402) == 402)
    }

    /// Without the window's width the trailing inset is taken to overlap the view; the leading one is still judged
    /// from the frame.
    @Test func withoutTheWindowWidthOnlyTheTrailingInsetComesOffDirectly() {
        let beside = CGRect(x: 310, y: 0, width: 434, height: 1000)
        #expect(UsableWidth.of(width: 434, leading: 310, trailing: 0, frameInWindow: beside, windowWidth: nil) == 434)
        let under = CGRect(x: 0, y: 0, width: 800, height: 600)
        #expect(UsableWidth.of(width: 800, leading: 0, trailing: 200, frameInWindow: under, windowWidth: nil) == 600)
    }

    @Test func insetsLargerThanTheViewNeverGoNegative() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(UsableWidth.of(width: 100, leading: 300, trailing: 300, frameInWindow: frame, windowWidth: 100) == 0)
    }
}
