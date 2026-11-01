import Testing
import UIKit
import UniformTypeIdentifiers
@testable import lily

/// `ImageFile` decodes a picture file off the main actor at the side a view needs, never at the size the file declares;
/// a file that is no picture, or no file, is refused, and one declaring more pixels than the cap is refused unread.
@MainActor
struct ImageFileTests {
    private typealias Caps = AppConfig.Chat.Attachments
    private let directory = FileManager.default.temporaryDirectory.appending(path: "image-file-\(UUID().uuidString)")

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func picture(_ width: Int, _ height: Int, _ type: UTType = .png, orientation: Int? = nil) throws -> URL {
        try ImageFiles.blankPicture(width: width, height: height, type: type, orientation: orientation, in: directory)
    }

    private func pixels(of image: UIImage) throws -> (width: Int, height: Int) {
        let bitmap = try #require(image.cgImage)
        return (bitmap.width, bitmap.height)
    }

    /// The bound never upscales: a small picture keeps its pixels.
    @Test func aPictureFileIsDecodedToItsPixels() async throws {
        let image = try await ImageFile.load(picture(60, 30), maxDimension: Caps.thumbnailMaxDimension)
        #expect(try pixels(of: image) == (60, 30))
    }

    @Test func aFileThatIsNoPictureIsRefused() async throws {
        let url = directory.appending(path: "words.png")
        try Data("not a picture".utf8).write(to: url)
        await #expect(throws: ImageFile.Refusal.notAPicture) {
            try await ImageFile.load(url, maxDimension: Caps.thumbnailMaxDimension)
        }
    }

    @Test func aMissingFileIsRefused() async {
        await #expect(throws: ImageFile.Refusal.notAPicture) {
            try await ImageFile.load(directory.appending(path: "missing.png"), maxDimension: Caps.thumbnailMaxDimension)
        }
    }

    /// The view's side bounds the bitmap, whatever the file declares: a tile's bound for a tile, the picture's for a page.
    @Test func aPictureLargerThanTheBoundIsDecodedWithinIt() async throws {
        let url = try picture(3000, 1500)
        let tile = try await ImageFile.load(url, maxDimension: Caps.thumbnailMaxDimension)
        let page = try await ImageFile.load(url, maxDimension: Caps.imageMaxDimension)
        #expect(try pixels(of: tile) == (512, 256))
        #expect(try pixels(of: page) == (2048, 1024))
    }

    /// The cap is read off the header, at either bound; a GIF is the type whose decode would build the whole canvas first.
    @Test func aPictureDeclaringMorePixelsThanTheCapIsRefusedUnread() async throws {
        let url = try picture(5000, 5000, .gif)
        for bound in [Caps.thumbnailMaxDimension, Caps.imageMaxDimension] {
            await #expect(throws: ImageFile.Refusal.overThePixelCap(width: 5000, height: 5000)) {
                try await ImageFile.load(url, maxDimension: bound)
            }
        }
    }

    /// The comparison is `<=`: exactly the cap is still a picture.
    @Test func aPictureAtTheCapIsStillDecoded() async throws {
        let image = try await ImageFile.load(picture(4000, 4000), maxDimension: Caps.thumbnailMaxDimension)
        #expect(try pixels(of: image) == (512, 512))
    }

    /// Headers declaring 100000 x 100000 pixels, or sides whose product overflows `Int`, with no pixel data behind them:
    /// refused without a decode or a trap, whether ImageIO's own header limits refuse them first (`notAPicture`) or the
    /// cap does (`overThePixelCap`); the cap's arithmetic is pinned on its own below.
    @Test func anAbsurdDeclaredSizeIsRefusedUnread() async throws {
        for side in [100_000, UInt32.max] as [UInt32] {
            let bomb = directory.appending(path: "declared-\(side).png")
            try ImageFiles.pngHeaderOnly(width: side, height: side).write(to: bomb)
            await #expect(throws: ImageFile.Refusal.self) {
                try await ImageFile.load(bomb, maxDimension: Caps.thumbnailMaxDimension)
            }
        }
    }

    /// The cap's arithmetic on its own: sides a header can declare but no bitmap could hold.
    @Test func thePixelCapRefusesOverflowingAndEmptySizes() {
        #expect(ImageFile.isWithinPixelCap(width: 4000, height: 4000))
        #expect(!ImageFile.isWithinPixelCap(width: 4001, height: 4000))
        #expect(!ImageFile.isWithinPixelCap(width: Int.max, height: 2), "the product overflows")
        #expect(!ImageFile.isWithinPixelCap(width: Int(UInt32.max), height: Int(UInt32.max)))
        #expect(!ImageFile.isWithinPixelCap(width: 0, height: 4000))
        #expect(!ImageFile.isWithinPixelCap(width: -1, height: -1), "two negative sides multiply to a positive count")
    }

    /// Another client's portrait photo, stored as landscape pixels plus an orientation tag, shows upright: the tag is
    /// applied in the pixels, and `size` is the oriented size the viewer's geometry reads.
    @Test func anEXIFRotatedPictureIsDecodedUpright() async throws {
        let url = try picture(600, 400, .jpeg, orientation: 6)
        let image = try await ImageFile.load(url, maxDimension: Caps.imageMaxDimension)
        #expect(try pixels(of: image) == (400, 600))
        #expect(image.imageOrientation == .up)
        #expect(image.size == CGSize(width: 400, height: 600))
    }
}
