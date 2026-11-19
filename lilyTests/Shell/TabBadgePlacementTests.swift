import CoreGraphics
import Testing
@testable import lily

@MainActor
struct TabBadgePlacementTests {
    /// The owner-tuned offset from the drawn glyph's top-right corner, anchored on the glyph view's centre: for the
    /// measured chat glyph box (centre (47, 20), 30 by 26 at point size 23) the capsule centre lands where the
    /// composite drew it.
    @Test func theCapsuleCentreIsTheTunedOffsetFromTheGlyphsTopRight() {
        let center = TabBadgePlacement.capsuleCenter(glyphCenter: CGPoint(x: 47, y: 20),
                                                     glyphSize: CGSize(width: 30, height: 26))
        let offset = DesignTokens.TabBar.badgeCenterOffset
        #expect(center == CGPoint(x: 47 + 15 + offset.x, y: 20 - 13 + offset.y))
    }

    /// The platter holds two parallel item trees at identical frames (the SE dump: columns 4, 90, 176 twice over),
    /// so items count as x-columns; Chats is the column at its tab index.
    @Test func duplicateItemTreesCollapseIntoColumnsAndChatsIsItsIndex() {
        let column = TabBadgePlacement.chatsColumn(itemColumns: [4, 90, 176, 4, 90, 176],
                                                   chatIndex: 2,
                                                   expectedTabs: 3)
        #expect(column == 176)
    }

    /// Any other shape is not trusted: the overlay stands down and the count stays composited into the glyph.
    @Test func anUnexpectedItemShapeAnswersNothing() {
        #expect(TabBadgePlacement.chatsColumn(itemColumns: [4, 90], chatIndex: 2, expectedTabs: 3) == nil)
        #expect(TabBadgePlacement.chatsColumn(itemColumns: [4, 90, 176, 262], chatIndex: 2, expectedTabs: 3) == nil)
        #expect(TabBadgePlacement.chatsColumn(itemColumns: [], chatIndex: 2, expectedTabs: 3) == nil)
        #expect(TabBadgePlacement.chatsColumn(itemColumns: [4, 90, 176], chatIndex: 3, expectedTabs: 3) == nil)
    }
}
