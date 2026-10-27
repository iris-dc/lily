import Testing
@testable import lily

/// Which pin the bar shows, where a tap steps, and which segments the stripe draws.
struct PinnedBarPositionTests {
    @Test func theNewestShowsUnlessATapSteppedBackAndAStaleIndexClamps() {
        #expect(PinnedBarPosition.shown(nil, count: 3) == 2)
        #expect(PinnedBarPosition.shown(1, count: 3) == 1)
        #expect(PinnedBarPosition.shown(5, count: 3) == 2, "an index from before pins were unpinned")
        #expect(PinnedBarPosition.shown(0, count: 1) == 0)
    }

    @Test func aTapStepsToThePinBeforeAndRoundToTheNewestAfterTheOldest() {
        #expect(PinnedBarPosition.steppedBack(from: 2, count: 3) == 1)
        #expect(PinnedBarPosition.steppedBack(from: 0, count: 3) == 2)
        #expect(PinnedBarPosition.steppedBack(from: 0, count: 1) == 0)
    }

    @Test func theStripeShowsEveryPinUpToItsSegmentsAndAWindowAroundTheShownOnePastThem() {
        #expect(PinnedBarPosition.stripeWindow(shown: 1, count: 3, maxSegments: 4) == 0..<3)
        #expect(PinnedBarPosition.stripeWindow(shown: 5, count: 6, maxSegments: 4) == 2..<6, "the newest shown: the last four")
        #expect(PinnedBarPosition.stripeWindow(shown: 0, count: 6, maxSegments: 4) == 0..<4, "the oldest shown: the first four")
        #expect(PinnedBarPosition.stripeWindow(shown: 3, count: 6, maxSegments: 4) == 0..<4)
        #expect(PinnedBarPosition.stripeWindow(shown: 4, count: 6, maxSegments: 4) == 1..<5)
    }
}
