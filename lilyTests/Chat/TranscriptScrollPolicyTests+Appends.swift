import Foundation
import Testing
@testable import lily

/// What the policy does around an appended row's slide.
extension TranscriptScrollPolicyTests {
    /// The anchor goes back only once two reports agree on the layout; a height or inset still changing is not settled.
    @Test func theLayoutHasSettledWhenTwoReportsAgree() {
        let first = snapshot(contentHeight: 2_083)
        #expect(!TranscriptScrollPolicy.layoutHasSettled(from: snapshot(), to: first))
        #expect(!TranscriptScrollPolicy.layoutHasSettled(from: first, to: snapshot(contentHeight: 2_057)))
        let corrected = snapshot(contentHeight: 2_057)
        let moved = snapshot(offsetY: 20, contentHeight: 2_057)
        let shorterComposer = snapshot(offsetY: 20, contentHeight: 2_057, bottomInset: 60)
        #expect(TranscriptScrollPolicy.layoutHasSettled(from: corrected, to: moved), "a scroll alone is settled")
        #expect(!TranscriptScrollPolicy.layoutHasSettled(from: moved, to: shorterComposer))
    }

    /// The lazy stack lays an appended row out at an estimated height first and corrects it a report later: that shrink
    /// is the slide's to absorb, not a pin's, which would snap the slide to its end; a later shrink pins as ever.
    @Test func theReportAfterASlideMayShrinkWithoutAPin() {
        var policy = settled()
        let estimated = snapshot(contentHeight: 2_083)
        #expect(policy.geometryChanged(from: snapshot(), to: estimated, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .animateToBottom)
        let corrected = snapshot(contentHeight: 2_057)
        #expect(policy.geometryChanged(from: estimated, to: corrected, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        let deleted = snapshot(contentHeight: 2_030)
        #expect(policy.geometryChanged(from: corrected, to: deleted, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .scrollToBottom)
        // A slide followed by anything but a shrink spends the allowance.
        let grownAgain = snapshot(contentHeight: 2_100)
        #expect(policy.geometryChanged(from: deleted, to: grownAgain, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .animateToBottom)
        let moved = snapshot(offsetY: 10, contentHeight: 2_100)
        #expect(policy.geometryChanged(from: grownAgain, to: moved, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        let shrunkLater = snapshot(offsetY: 10, contentHeight: 2_080)
        #expect(policy.geometryChanged(from: moved, to: shrunkLater, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .scrollToBottom)
    }
}
