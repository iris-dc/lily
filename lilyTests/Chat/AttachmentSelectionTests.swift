import Foundation
import Testing
@testable import lily

/// Which pictures a tap on a gallery tile opens and where the pages start: at the tapped picture, at the first hidden one
/// from the "+N" tile, never at a file; and nothing for a message of files alone or a tile the grid does not draw.
struct AttachmentSelectionTests {
    private let pictures = (1...5).map { Self.picture("p\($0)") }

    @Test func theOverflowTileOpensTheFifthPicture() throws {
        let message = ChatMessage.fixture(id: "m1", attachments: pictures)

        let selection = try #require(AttachmentSelection(message: message, tappedTile: 3))

        #expect(selection.start == 4)
        #expect(selection.id == "p5" && selection.current.id == "p5")
        #expect(selection.media.count == 5, "every picture stays reachable behind the tile")
    }

    @Test func aTileOpensItsOwnPictureWhenNothingIsHidden() throws {
        let four = ChatMessage.fixture(id: "m1", attachments: Array(pictures.prefix(4)))

        let last = try #require(AttachmentSelection(message: four, tappedTile: 3))
        let first = try #require(AttachmentSelection(message: four, tappedTile: 0))
        let single = try #require(AttachmentSelection(message: .fixture(id: "m2", attachments: [pictures[0]]), tappedTile: 0))

        #expect(last.start == 3 && last.id == "p4")
        #expect(first.start == 0 && first.id == "p1")
        #expect(single.start == 0 && single.media == [pictures[0]])
    }

    @Test func filesAreLeftOutOfThePagesAndTheTilesStillLineUp() throws {
        let picture = Self.picture("a")
        let video = lily.Attachment.videoFixture(id: "v")
        let message = ChatMessage.fixture(id: "m1", attachments: [picture, .fileFixture(id: "f"), video])

        let selection = try #require(AttachmentSelection(message: message, tappedTile: 1))

        #expect(selection.media == [picture, video])
        #expect(selection.start == 1 && selection.id == "v")
    }

    @Test func aMessageOfFilesAloneOrAnUndrawnTileSelectsNothing() {
        let files = ChatMessage.fixture(id: "m1",
                                        attachments: [.fileFixture(id: "f1"), .fileFixture(id: "f2", fileName: "notes.txt")])
        let five = ChatMessage.fixture(id: "m2", attachments: pictures)

        #expect(AttachmentSelection(message: files, tappedTile: 0) == nil)
        #expect(AttachmentSelection(message: five, tappedTile: 4) == nil, "the fifth picture has no tile of its own")
        #expect(AttachmentSelection(message: five, tappedTile: -1) == nil)
    }

    private static func picture(_ id: String) -> lily.Attachment {
        .fixture(id: id, url: URL(string: "https://files.test/chat/g/\(id)")!)
    }
}
