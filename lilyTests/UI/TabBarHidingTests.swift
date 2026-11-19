import Testing
@testable import lily

@MainActor
struct TabBarHidingTests {
    @Test func aRegisteredScreenHidesTheBarAtItsDepthAndAboveIt() {
        let hiding = TabBarHiding()
        hiding.hide("room", at: 1)
        #expect(hiding.hides(at: 1))
        #expect(!hiding.hides(at: 0), "the root under the room shows the bar")
        #expect(hiding.hides(at: 2), "a profile pushed over the room stays in the room's flow")
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
        #expect(hiding.hides(at: 2))
        hiding.prune(above: 1)
        #expect(hiding.hides(at: 1), "popping back onto the room keeps it")
        hiding.prune(above: 0)
        #expect(!hiding.hides(at: 1))
    }

    @Test func aScreenAppearingAgainKeepsItsFirstDepth() {
        let hiding = TabBarHiding()
        hiding.hide("room", at: 1)
        hiding.hide("room", at: 2)
        hiding.prune(above: 1)
        #expect(hiding.hides(at: 1), "the stale deeper depth did not replace the room's own, or the prune would drop it")
    }

    @Test func twoScreensAtOneDepthEachHideTheBar() {
        let hiding = TabBarHiding()
        hiding.hide("first", at: 1)
        hiding.hide("second", at: 1)
        #expect(hiding.hides(at: 1))
        hiding.prune(above: 0)
        #expect(!hiding.hides(at: 1))
    }

    @Test func aScreenPushedOverTheRoomAgainAfterAPopStaysWithoutTheBar() {
        let hiding = TabBarHiding()
        hiding.hide("room", at: 1)
        hiding.prune(above: 2)
        hiding.prune(above: 1)
        hiding.prune(above: 2)
        #expect(hiding.hides(at: 2), "a profile pushed, popped and pushed again stays in the room's flow")
    }

    @Test func anItemPushedScreenIsFreedByItsRelease() {
        let hiding = TabBarHiding()
        hiding.hide("chat", at: 1)
        #expect(hiding.hides(at: 1))
        hiding.release("chat")
        #expect(!hiding.hides(at: 1), "an item pop moves no path, so no prune fires: the release frees the hide")
    }

    /// The registry trusts its one releasing caller (`chatDestination`, on its cleared item binding — a signal
    /// SwiftUI sends on the pop alone, never on a tab switch, never under a cover): no depth guard, a release frees
    /// the screen wherever the stack stands.
    @Test func aReleaseFreesTheScreenWhateverTheStacksDepth() {
        let hiding = TabBarHiding()
        hiding.hide("chat", at: 1)
        hiding.prune(above: 3)
        hiding.release("chat")
        #expect(!hiding.hides(at: 3))
    }

    @Test func aReleaseAfterAPathPopsPruneIsANoOp() {
        let hiding = TabBarHiding()
        hiding.hide("room", at: 1)
        hiding.prune(above: 0)
        hiding.release("room")
        #expect(!hiding.hides(at: 1))
    }

    @Test func releasingAnotherScreensTokenChangesNothing() {
        let hiding = TabBarHiding()
        hiding.hide("room", at: 1)
        hiding.release("profile")
        #expect(hiding.hides(at: 1))
    }

    @Test func twoHidingScreensAtDifferentDepthsLeaveWithTheirOwnPops() {
        let hiding = TabBarHiding()
        hiding.hide("room", at: 1)
        hiding.hide("inbox", at: 3)
        hiding.prune(above: 2)
        #expect(hiding.hides(at: 2), "the room under the detail still hides the bar")
        hiding.prune(above: 0)
        #expect(!hiding.hides(at: 1) && !hiding.hides(at: 3))
    }
}
