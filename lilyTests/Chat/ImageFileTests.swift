import Testing
import UIKit
@testable import lily

/// `ImageFile` reads and decodes a picture file off the main actor; a file that is no picture, or no file, is `nil`.
@MainActor
struct ImageFileTests {
    private let url = FileManager.default.temporaryDirectory.appending(path: "image-file-\(UUID().uuidString).png")

    @Test func aPictureFileIsDecodedToItsPixels() async throws {
        let size = CGSize(width: 20, height: 10)
        try png(size).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = await ImageFile.load(url)

        let image = try #require(loaded)
        let scale = UIGraphicsImageRendererFormat.default().scale
        #expect(image.cgImage?.width == Int(size.width * scale))
        #expect(image.cgImage?.height == Int(size.height * scale))
    }

    @Test func aFileThatIsNoPictureAnswersNil() async throws {
        try Data("not a picture".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = await ImageFile.load(url)

        #expect(loaded == nil)
    }

    @Test func aMissingFileAnswersNil() async {
        let loaded = await ImageFile.load(url)

        #expect(loaded == nil)
    }

    private func png(_ size: CGSize) -> Data {
        UIGraphicsImageRenderer(size: size, format: UIGraphicsImageRendererFormat.default()).pngData { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
