import Testing
@testable import lily

@MainActor
struct TabBarHidingTests {
    @Test func aRegisteredScreenHidesTheBarAtItsDepthOnly() {
        let hiding = TabBarHiding()
        hiding.hide("room", at: 1)
        #expect(hiding.hides(at: 1))
        #expect(!hiding.hides(at: 0))
        #expect(!hiding.hides(at: 2))
    }

    @Test func aPopBelowTheScreenForgetsIt() {
        let hiding = TabBarHiding()
        hiding.hide("room", at: 1)
        hiding.prune(above: 0)
        #expect(!hiding.hides(at: 1))
    }

    @Test func aScreenCoveredByAPushKeepsItsPlaceUntilItIsPopped() {
        let hiding = TabBarHiding()
        hiding.hide("room", at: 1)
        hiding.prune(above: 2)
        #expect(hiding.hides(at: 1), "the detail pushed over the room changes nothing at the room's depth")
        #expect(!hiding.hides(at: 2))
        hiding.prune(above: 1)
        #expect(hiding.hides(at: 1), "popping back onto the room keeps it")
        hiding.prune(above: 0)
        #expect(!hiding.hides(at: 1))
    }

    @Test func aScreenAppearingAgainKeepsItsFirstDepth() {
        let hiding = TabBarHiding()
        hiding.hide("room", at: 1)
        hiding.hide("room", at: 2)
        #expect(hiding.hides(at: 1))
        #expect(!hiding.hides(at: 2))
    }

    @Test func twoScreensAtOneDepthEachHideTheBar() {
        let hiding = TabBarHiding()
        hiding.hide("first", at: 1)
        hiding.hide("second", at: 1)
        #expect(hiding.hides(at: 1))
        hiding.prune(above: 0)
        #expect(!hiding.hides(at: 1))
    }
}
