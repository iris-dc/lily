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

    /// The twin draws wherever the platter shows settled or arriving; the capsule rides only a collapse morph.
    @Test func theTwinFollowsThePaneStatesAndTheLastUnhiddenPane() {
        func twin(_ platterHidden: Bool, _ circleHidden: Bool?, _ last: TabBadgePlacement.Pane?) -> Bool {
            TabBadgePlacement.twinShows(platterHidden: platterHidden,
                                        circleHidden: circleHidden,
                                        lastUnhidden: last)
        }
        #expect(twin(false, true, nil), "expanded rest: the twin draws, and every tab switch keeps it")
        #expect(twin(false, true, .circle), "a settled rest ignores stale morph history")
        #expect(twin(false, nil, nil), "no circle pane on screen reads as hidden")
        #expect(twin(false, false, .platter), "expand morph: the badge is full from the first frame")
        #expect(!twin(false, false, .circle), "collapse morph: the capsule rides and fades with the pane")
        #expect(!twin(false, false, nil), "an unknown direction errs to the ride")
        #expect(!twin(true, false, .platter), "minimized rest: the bare circle stays bare")
        #expect(!twin(true, true, nil))
    }

    /// The three-valued drawer: stood down iff not hosting — the carriers are then the hand-back's to remove,
    /// never flipped early — and hosting, the pane rule picks the twin or the ride.
    @Test func theDrawerStandsDownOnlyWhenNotHosting() {
        func drawer(_ hosting: Bool, _ platter: Bool, _ circle: Bool?, _ last: TabBadgePlacement.Pane?)
            -> TabBadgePlacement.Drawer {
            TabBadgePlacement.badgeDrawer(hosting: hosting,
                                          platterHidden: platter,
                                          circleHidden: circle,
                                          lastUnhidden: last)
        }
        #expect(drawer(false, false, true, nil) == .standDown)
        #expect(drawer(false, true, false, .platter) == .standDown)
        #expect(drawer(false, false, false, .circle) == .standDown)
        #expect(drawer(true, false, true, nil) == .twin, "expanded rest")
        #expect(drawer(true, false, nil, nil) == .twin, "no circle pane reads as hidden")
        #expect(drawer(true, false, false, .platter) == .twin, "expand morph")
        #expect(drawer(true, false, false, .circle) == .ride, "collapse morph")
        #expect(drawer(true, false, false, nil) == .ride, "unknown direction errs to the ride")
        #expect(drawer(true, true, false, .platter) == .ride, "minimized rest never twins")
    }
}
