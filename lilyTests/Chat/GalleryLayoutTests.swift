import Foundation
import Testing
@testable import lily

/// How many tiles a gallery draws and how: one alone, two side by side, three with the last spanning the row, four as
/// a grid, more than four behind a "+N"; and which attachments are tiles at all (pictures and videos) against cards (files).
struct GalleryLayoutTests {
    @Test func oneIsSingleAndTwoShareARow() {
        let one = GalleryLayout(count: 1)
        #expect(one.isSingle && one.shownCount == 1 && one.rows == [[0]] && !one.spansRow(0) && one.hiddenCount == 0)

        let two = GalleryLayout(count: 2)
        #expect(!two.isSingle && two.rows == [[0, 1]] && !two.spansRow(1))
    }

    @Test func threeSpanTheLastRowAndFourFillTheGrid() {
        let three = GalleryLayout(count: 3)
        #expect(three.rows == [[0, 1], [2]] && three.spansRow(2) && !three.spansRow(0) && !three.showsOverflow(at: 2))

        let four = GalleryLayout(count: 4)
        #expect(four.rows == [[0, 1], [2, 3]] && !four.spansRow(3) && four.hiddenCount == 0)
    }

    @Test func moreThanFourHideBehindTheLastTile() {
        let seven = GalleryLayout(count: 7)
        #expect(seven.shownCount == 4 && seven.hiddenCount == 3 && seven.rows == [[0, 1], [2, 3]])
        #expect(seven.showsOverflow(at: 3) && !seven.showsOverflow(at: 2))
        #expect(AppBranding.Chat.Attachments.more(seven.hiddenCount) == "+3")
    }

    @Test func picturesAndVideosAreTilesFilesAreCards() {
        let mixed = GalleryLayout.partition([.image, .file, .video, .file, .image])
        #expect(mixed.media == [0, 2, 4] && mixed.files == [1, 3])
        #expect(GalleryLayout(count: mixed.media.count).rows == [[0, 1], [2]], "the grid is laid out over the media alone")

        let filesOnly = GalleryLayout.partition([.file, .file])
        #expect(filesOnly.media.isEmpty && filesOnly.files == [0, 1])
        #expect(GalleryLayout.partition([]) == GalleryLayout.Partition(media: [], files: []))
        #expect(AttachmentKind.image.isMedia && AttachmentKind.video.isMedia && !AttachmentKind.file.isMedia)
    }
}
