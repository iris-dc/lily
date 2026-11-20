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

    /// Both parallel trees must be whole: every column carries the same number of controls, or the overlay
    /// resolves nothing and retries — a partial tree would pin the count to whichever copy happened to resolve.
    @Test func everyColumnMustCarryTheSameNumberOfControls() {
        #expect(TabBadgePlacement.treeCount(itemColumns: [4, 90, 176, 4, 90, 176], expectedTabs: 3) == 2)
        #expect(TabBadgePlacement.treeCount(itemColumns: [4, 90, 176], expectedTabs: 3) == 1)
        #expect(TabBadgePlacement.treeCount(itemColumns: [4, 90, 176, 4], expectedTabs: 3) == nil)
        #expect(TabBadgePlacement.treeCount(itemColumns: [4, 90, 176, 4, 90], expectedTabs: 3) == nil)
        #expect(TabBadgePlacement.treeCount(itemColumns: [], expectedTabs: 3) == nil)
        #expect(TabBadgePlacement.treeCount(itemColumns: [4, 90], expectedTabs: 3) == nil)
    }

    /// The platter is the one pane that scales with the bar (about three quarters of it on every device): the
    /// minimized circle (48 pt), the ~100 pt tab-switch transient and a pre-layout zero-width pane never host the
    /// capsule, and an unlaid-out bar trusts nothing.
    @Test func onlyAPaneSpanningMostOfTheBarIsThePlatter() {
        #expect(TabBadgePlacement.isPlatter(paneWidth: 280, barWidth: 375))
        #expect(TabBadgePlacement.isPlatter(paneWidth: 187.5, barWidth: 375))
        #expect(!TabBadgePlacement.isPlatter(paneWidth: 100, barWidth: 375))
        #expect(!TabBadgePlacement.isPlatter(paneWidth: 48, barWidth: 375))
        #expect(!TabBadgePlacement.isPlatter(paneWidth: 0, barWidth: 375))
        #expect(!TabBadgePlacement.isPlatter(paneWidth: 300, barWidth: 0))
    }
}
