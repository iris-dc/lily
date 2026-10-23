import SwiftUI
import Testing
@testable import lily

/// Where the viewer draws its picture on the way in and out: fitted to its page at 0, on its tile at 1, dragged up or
/// down only at full size, fading where there is no tile.
struct ViewerGeometryTests {
    private let page = CGRect(x: 0, y: 62, width: 402, height: 778)
    private let tile = TileGeometry(
        frame: CGRect(x: 180, y: 300, width: 200, height: 150),
        radii: RectangleCornerRadii(topLeading: 15, bottomLeading: 4, bottomTrailing: 4, topTrailing: 15)
    )

    @Test func atZeroThePictureIsFittedToItsPage() {
        let open = ViewerGeometry(page: page, aspectRatio: 1.5, tile: tile, progress: 0, drag: 0)
        #expect(open.rect == CGRect(x: 0, y: 62 + (778 - 268) / 2, width: 402, height: 268))
        #expect(open.radii.topLeading == 0 && open.opacity == 1)
    }

    @Test func atOneThePictureIsTheTile() {
        let landed = ViewerGeometry(page: page, aspectRatio: 1.5, tile: tile, progress: 1, drag: 120)
        #expect(landed.rect == tile.frame)
        #expect(landed.radii == tile.radii)
    }

    /// Up or down only, never sideways, and at full size.
    @Test func aDragMovesThePictureUpOrDownAtFullSize() {
        let open = ViewerGeometry(page: page, aspectRatio: 1.5, tile: tile, progress: 0, drag: 0)
        let down = ViewerGeometry(page: page, aspectRatio: 1.5, tile: tile, progress: 0, drag: 90)
        let up = ViewerGeometry(page: page, aspectRatio: 1.5, tile: tile, progress: 0, drag: -90)
        #expect(down.rect == open.rect.offsetBy(dx: 0, dy: 90))
        #expect(up.rect == open.rect.offsetBy(dx: 0, dy: -90))
    }

    /// Halfway is halfway in every value, so an animation of the progress draws the path.
    @Test func halfwayIsHalfwayInEveryValue() {
        let open = ViewerGeometry(page: page, aspectRatio: 1.5, tile: tile, progress: 0, drag: 0)
        let half = ViewerGeometry(page: page, aspectRatio: 1.5, tile: tile, progress: 0.5, drag: 0)
        #expect(half.rect.midX == (open.rect.midX + tile.frame.midX) / 2)
        #expect(half.rect.width == (open.rect.width + tile.frame.width) / 2)
        #expect(half.radii.topLeading == 7.5)
    }

    @Test func withoutATileThePictureFadesWhereItIs() {
        let fading = ViewerGeometry(page: page, aspectRatio: nil, tile: nil, progress: 0.25, drag: 40)
        #expect(fading.rect == page.offsetBy(dx: 0, dy: 40), "an unknown shape fills the page")
        #expect(fading.opacity == 0.75)
    }

    /// The black goes with the picture onto its tile, and fades as it is dragged, gone at the fade distance.
    @Test func theBlackFadesOnTheWayAndWithTheDrag() {
        let fade = DesignTokens.Layout.viewerFadeDistance
        #expect(ViewerGeometry.backdropOpacity(progress: 0, drag: 0) == 1)
        #expect(ViewerGeometry.backdropOpacity(progress: 1, drag: 0) == 0)
        #expect(ViewerGeometry.backdropOpacity(progress: 0, drag: -fade / 2) == 0.5)
        #expect(ViewerGeometry.backdropOpacity(progress: 0, drag: fade * 2) == 0)
    }

    @Test func aTallPictureFitsTheHeightAndATallPageTheWidth() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 800)
        #expect(ViewerGeometry.fit(0.25, in: bounds) == CGRect(x: 100, y: 0, width: 200, height: 800))
        #expect(ViewerGeometry.fit(2, in: bounds) == CGRect(x: 0, y: 300, width: 400, height: 200))
        #expect(ViewerGeometry.fit(0, in: bounds) == bounds)
    }
}
