import Testing
import SwiftUI
@testable import lily

/// What a chat shares with its viewer: tiles' places by every attachment they stand for, and thumbnails only while
/// their tile holds them.
@MainActor
struct ViewerHeroTests {
    @Test func aTileIsPlacedForEveryAttachmentItStandsForUntilItLeaves() {
        let hero = ViewerHero()
        let corners = RectangleCornerRadii(topLeading: 1, bottomLeading: 1, bottomTrailing: 1, topTrailing: 1)
        let geometry = TileGeometry(frame: CGRect(x: 1, y: 2, width: 3, height: 4), radii: corners)
        hero.place(geometry, for: ["a4", "a5", "a6"])
        #expect(hero.tiles["a5"] == geometry && hero.tiles["a6"] == geometry)

        hero.place(nil, for: ["a4", "a5", "a6"])
        #expect(hero.tiles.isEmpty)
    }

    @Test func aThumbnailIsHeldOnlyWhileItsTileHoldsIt() {
        let hero = ViewerHero()
        var heldWhileAlive = false
        autoreleasepool {
            let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }
            hero.noteThumbnail(image, for: "a1")
            heldWhileAlive = hero.thumbnail(for: "a1") === image
        }
        let heldAfter = autoreleasepool { hero.thumbnail(for: "a1") != nil }

        #expect(heldWhileAlive)
        #expect(!heldAfter, "the tile let it go, so does the viewer")
    }
}
