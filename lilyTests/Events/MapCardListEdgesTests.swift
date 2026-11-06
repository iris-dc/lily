import CoreGraphics
import Testing
@testable import lily

@MainActor
@Suite("Map card list edges")
struct MapCardListEdgesTests {
    @Test func aListThatFitsHasNothingBeyondEitherEdge() {
        let edges = MapCardListEdges(offset: 0, contentHeight: 300, containerHeight: 300)
        #expect(edges == .none)
    }

    @Test func aTallListAtItsTopHasMoreBelowOnly() {
        let edges = MapCardListEdges(offset: 0, contentHeight: 700, containerHeight: 400)
        #expect(!edges.hasMoreAbove)
        #expect(edges.hasMoreBelow)
    }

    @Test func midwayThereIsMoreOnBothSides() {
        let edges = MapCardListEdges(offset: 150, contentHeight: 700, containerHeight: 400)
        #expect(edges.hasMoreAbove)
        #expect(edges.hasMoreBelow)
    }

    @Test func atTheEndOnlyAboveRemainsAndRoundingDoesNotCount() {
        let edges = MapCardListEdges(offset: 299.6, contentHeight: 700, containerHeight: 400)
        #expect(edges.hasMoreAbove)
        #expect(!edges.hasMoreBelow)
        #expect(MapCardListEdges(offset: 0.4, contentHeight: 300.5, containerHeight: 300) == .none)
    }

    @Test func oneCardTallerThanTheListStillHasMoreBelow() {
        let edges = MapCardListEdges(offset: 0, contentHeight: 1_800, containerHeight: 400)
        #expect(edges.hasMoreBelow)
    }

    @Test func theCountIsTheCardsAfterTheLastOneInView() {
        let ids = ["a", "b", "c", "d", "e", "f", "g"]
        #expect(MapCardListEdges.cardsBelow(in: ids, visible: ["a", "b", "c"]) == 4)
        #expect(MapCardListEdges.cardsBelow(in: ids, visible: ["d", "e", "f"]) == 1)
    }

    @Test func noCardIsLeftOnceTheLastIsInViewOrThereIsOnlyOne() {
        #expect(MapCardListEdges.cardsBelow(in: ["a", "b", "c", "d"], visible: ["c", "d"]) == 0)
        #expect(MapCardListEdges.cardsBelow(in: ["a"], visible: []) == 0)
        #expect(MapCardListEdges.cardsBelow(in: ["a"], visible: ["a"]) == 0)
    }

    @Test func beforeAnyReportTheFirstCardCountsAsInView() {
        #expect(MapCardListEdges.cardsBelow(in: ["a", "b", "c", "d"], visible: []) == 3)
    }
}
