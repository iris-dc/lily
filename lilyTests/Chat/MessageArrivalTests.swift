import SwiftUI
import Testing
@testable import lily

/// What leaves the transcript and the scroll that follows an arrival under Reduce Motion: a discarded row only fades, and
/// the spring is none.
struct MessageArrivalTests {
    @Test func theRemovalKeepsItsSizeUnderReducedMotion() {
        #expect(MessageRemovalTransition.leavingScale(motion: .reduced) == 1)
        #expect(MessageRemovalTransition.leavingScale(motion: .full) == DesignTokens.MessageArrival.scale)
    }

    @Test func theArrivalSpringIsNoneUnderReducedMotion() {
        #expect(Animation.messageArrival(.reduced) == nil)
        #expect(Animation.messageArrival(.full) != nil)
    }
}
