import CoreGraphics
import Testing
@testable import lily

/// The wrapping rules of `FlowLayout`, judged on sizes alone.
struct FlowArrangementTests {
    private typealias Row = FlowArrangement.Row

    @Test func threeItemsWrapAtTheEdgeAndSpacingSitsOnlyBetweenThem() {
        let rows = FlowArrangement.rows(for: [size(100), size(100), size(100)], in: 250, spacing: 8)
        #expect(rows == [Row(indices: [0, 1], width: 208, height: 20), Row(indices: [2], width: 100, height: 20)])
    }

    @Test func anItemThatExactlyFillsTheLineStaysOnIt() {
        let filling = FlowArrangement.rows(for: [size(100), size(142)], in: 250, spacing: 8)
        #expect(filling.map(\.width) == [250])
        let overrunning = FlowArrangement.rows(for: [size(100), size(143)], in: 250, spacing: 8)
        #expect(overrunning.count == 2)
    }

    @Test func aRowIsAsTallAsItsTallestItem() {
        let rows = FlowArrangement.rows(for: [size(100, 20), size(100, 40), size(100, 10)], in: 250, spacing: 8)
        #expect(rows.map(\.height) == [40, 10])
    }

    @Test func anItemWiderThanTheLineIsProposedTheLineWidth() {
        #expect(FlowArrangement.proposedWidth(ideal: 400, lineWidth: 300) == 300)
        #expect(FlowArrangement.proposedWidth(ideal: 200, lineWidth: 300) == nil)
        #expect(FlowArrangement.proposedWidth(ideal: 300, lineWidth: 300) == nil)
        #expect(FlowArrangement.proposedWidth(ideal: 400, lineWidth: .infinity) == nil)
    }

    @Test func anItemAsWideAsTheLineTakesARowOfItsOwn() {
        let rows = FlowArrangement.rows(for: [size(100), size(300), size(50)], in: 300, spacing: 8)
        #expect(rows.map(\.indices) == [[0], [1], [2]])
    }

    /// A view that refused to shrink to the proposed line width.
    @Test func anItemStillWiderThanTheLineIsNeverDropped() {
        let rows = FlowArrangement.rows(for: [size(350)], in: 300, spacing: 8)
        #expect(rows == [Row(indices: [0], width: 350, height: 20)])
    }

    @Test func noItemsGiveNoRowsAndNoHeight() {
        #expect(FlowArrangement.rows(for: [], in: 250, spacing: 8).isEmpty)
        #expect(FlowArrangement.height(of: [], rowSpacing: 8) == 0)
    }

    @Test func anUnboundedWidthGivesOneRowAtTheContentsWidth() {
        let rows = FlowArrangement.rows(for: [size(100), size(100), size(100)], in: .infinity, spacing: 8)
        #expect(rows.map(\.width) == [316])
    }

    @Test func theHeightSumsTheRowsWithRowSpacingBetweenThem() {
        let two = [Row(indices: [0], width: 100, height: 40), Row(indices: [1], width: 100, height: 10)]
        #expect(FlowArrangement.height(of: two, rowSpacing: 8) == 58)
        #expect(FlowArrangement.height(of: [two[0]], rowSpacing: 8) == 40)
    }

    private func size(_ width: CGFloat, _ height: CGFloat = 20) -> CGSize {
        CGSize(width: width, height: height)
    }
}
