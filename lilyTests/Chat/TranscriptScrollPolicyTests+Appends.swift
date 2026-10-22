import Foundation
import Testing
@testable import lily

/// What the policy does around an appended row's slide.
extension TranscriptScrollPolicyTests {
    /// An appended row grows the content below the fold (the transcript lifts the anchor for it): the reader who was at
    /// the bottom slides down to it, also when the anchor kept the bottom (the slide then has nowhere to go); growth
    /// under a reader who scrolled away moves nothing.
    @Test func slidesToGrowthOnlyWhenTheReaderWasAtTheBottom() {
        var policy = settled()
        let grown = snapshot(contentHeight: 2_300, isAtBottom: false)
        #expect(policy.geometryChanged(from: snapshot(), to: grown, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .animateToBottom)
        let anchored = snapshot(offsetY: 300, contentHeight: 2_300)
        #expect(policy.geometryChanged(from: snapshot(), to: anchored, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .animateToBottom)
        let readingBefore = snapshot(offsetY: 500, isAtBottom: false)
        let readingAfter = snapshot(offsetY: 500, contentHeight: 2_300, isAtBottom: false)
        #expect(policy.geometryChanged(from: readingBefore, to: readingAfter, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        // A send clears the composer: the inset shrinks in the report that grew the content, and the slide still wins.
        let shorterComposer = snapshot(contentHeight: 2_300, bottomInset: 60, isAtBottom: false)
        #expect(policy.geometryChanged(from: snapshot(),
                                       to: shorterComposer,
                                       hasRows: true,
                                       canLoadOlder: true,
                                       oldestID: oldest) == .animateToBottom)
    }

    /// The bubble before the appended row loses its time line a pass after the row lands, and that shrink is the
    /// slide's to absorb, not a pin's, which would snap the slide to its end; a fast display may report the slide's
    /// first frames in between, and they must not spend the allowance; a later shrink pins as ever.
    @Test func theLayoutChangeAfterASlideMayShrinkWithoutAPin() {
        var policy = settled()
        let landed = snapshot(contentHeight: 2_083)
        #expect(policy.geometryChanged(from: snapshot(), to: landed, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .animateToBottom)
        let sliding = snapshot(offsetY: 8, contentHeight: 2_083)
        #expect(policy.geometryChanged(from: landed, to: sliding, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none, "the slide's own frame changes no layout")
        let corrected = snapshot(offsetY: 8, contentHeight: 2_057)
        #expect(policy.geometryChanged(from: sliding, to: corrected, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none, "the time line going is absorbed")
        let deleted = snapshot(offsetY: 8, contentHeight: 2_030)
        #expect(policy.geometryChanged(from: corrected, to: deleted, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .scrollToBottom, "a later shrink pins")
    }

    /// The composer clears in a send: on a fast display its inset may report on its own between the row's two passes,
    /// and that report spends nothing, so the pass after is still absorbed. A keyboard rising pins as ever, the slide
    /// has no say over what covers the row.
    @Test func anInsetReportLeavesTheAllowanceStanding() {
        var policy = settled()
        let landed = snapshot(contentHeight: 2_083)
        _ = policy.geometryChanged(from: snapshot(), to: landed, hasRows: true, canLoadOlder: true, oldestID: oldest)
        let shorterComposer = snapshot(contentHeight: 2_083, bottomInset: 60)
        #expect(policy.geometryChanged(from: landed, to: shorterComposer, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        let corrected = snapshot(contentHeight: 2_057, bottomInset: 60)
        #expect(policy.geometryChanged(from: shorterComposer, to: corrected, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none, "the pass after the inset's report is absorbed")
        let keyboard = snapshot(contentHeight: 2_057, bottomInset: 400)
        #expect(policy.geometryChanged(from: corrected, to: keyboard, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .scrollToBottom)
    }

    /// A second growth report during the slide (the row's passes, a picture) asks for the slide again and leaves the
    /// allowance standing for the correction that follows.
    @Test func aSecondGrowthDuringTheSlideKeepsTheAllowance() {
        var policy = settled()
        let landed = snapshot(contentHeight: 2_083)
        _ = policy.geometryChanged(from: snapshot(), to: landed, hasRows: true, canLoadOlder: true, oldestID: oldest)
        let taller = snapshot(contentHeight: 2_100)
        #expect(policy.geometryChanged(from: landed, to: taller, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .animateToBottom)
        let corrected = snapshot(contentHeight: 2_074)
        #expect(policy.geometryChanged(from: taller, to: corrected, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
    }

    /// The allowance is the lifted anchor's: a slide no shrink followed (another member's row, the caller's first after a
    /// gap) leaves none behind once the anchor is back, so the next shrink at the bottom (a delete) pins.
    @Test func theAllowanceEndsWithTheAnchorsReturn() {
        var policy = settled()
        let landed = snapshot(contentHeight: 2_083)
        _ = policy.geometryChanged(from: snapshot(), to: landed, hasRows: true, canLoadOlder: true, oldestID: oldest)
        policy.anchorReturned()
        let deleted = snapshot(contentHeight: 2_040)
        #expect(policy.geometryChanged(from: landed, to: deleted, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .scrollToBottom)
    }
}
