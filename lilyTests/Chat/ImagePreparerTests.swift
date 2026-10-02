import Foundation
import ImageIO
import Testing
import UIKit
@testable import lily

/// Pictures through the preparer: a big PNG comes out as a JPEG within the longest side, with a thumbnail, both as
/// files; one over the byte cap is refused, as are bytes that are no picture.
@MainActor
struct ImagePreparerTests {
    private let logger = SpyLogger()
    private let directory = FileManager.default.temporaryDirectory.appending(path: "prepared-\(UUID().uuidString)")

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func makePreparer(limits: ImagePreparer.Limits = ImagePreparer.Limits()) -> ImagePreparer {
        ImagePreparer(limits: limits, directory: directory, logger: logger)
    }

    /// A PNG of `size` with a gradient, so the JPEG is not trivially small.
    private func png(_ size: CGSize) -> Data {
        UIGraphicsImageRenderer(size: size, format: UIGraphicsImageRendererFormat.default()).pngData { context in
            let colors = [UIColor.systemRed.cgColor, UIColor.systemBlue.cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil)!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
        }
    }

    private func dimensions(of url: URL) throws -> (width: Int, height: Int) {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        return (width, height)
    }

    @Test func aLargePNGBecomesAJPEGWithinTheLongestSide() async throws {
        let format = UIGraphicsImageRendererFormat.default()
        let scale = format.scale
        let data = png(CGSize(width: 4000 / scale, height: 3000 / scale))

        let draft = try await makePreparer().prepareImage(data, id: "p1")

        #expect(draft.id == "p1" && draft.kind == .image && draft.contentType == "image/jpeg" && draft.state == .preparing)
        #expect(draft.width == 2048 && draft.height == 1536)
        #expect(try dimensions(of: draft.fileURL) == (2048, 1536))
        let written = try Data(contentsOf: draft.fileURL)
        #expect(draft.sizeBytes == written.count && draft.sizeBytes > 0)
        #expect(draft.fileURL.lastPathComponent == "p1.jpg" && draft.fileURL.path().hasPrefix(directory.path()))
        let thumbnail = try #require(draft.thumbnailURL)
        let thumbnailSize = try dimensions(of: thumbnail)
        #expect(thumbnailSize.width == 512 && thumbnailSize.height == 384)
        let thumbnailBytes = try Data(contentsOf: thumbnail)
        #expect(draft.thumbnailSizeBytes == thumbnailBytes.count)
        #expect(draft.thumbnailSizeBytes.map { $0 <= AppConfig.Chat.Attachments.thumbnailMaxBytes } == true)
        #expect(logger.messages(in: .chat, at: .debug).contains("Attachment p1 prepared: \(draft.sizeBytes) B, 2048x1536"))
    }

    /// A picture already within the longest side keeps its size.
    @Test func aSmallPictureIsNotUpscaled() async throws {
        let scale = UIGraphicsImageRendererFormat.default().scale
        let draft = try await makePreparer().prepareImage(png(CGSize(width: 300 / scale, height: 200 / scale)), id: "p2")
        #expect(draft.width == 300 && draft.height == 200)
    }

    @Test func aPictureOverTheByteCapIsRefused() async {
        var limits = ImagePreparer.Limits()
        limits.maxBytes = 10
        let scale = UIGraphicsImageRendererFormat.default().scale
        let data = png(CGSize(width: 800 / scale, height: 600 / scale))

        await #expect(throws: AppError.attachmentTooLarge) { try await makePreparer(limits: limits).prepareImage(data, id: "p3") }
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "p3.jpg").path()))
    }

    @Test func bytesThatAreNoPictureAreRefused() async {
        await #expect(throws: AppError.attachmentTypeNotAllowed) {
            try await makePreparer().prepareImage(Data("not an image".utf8), id: "p4")
        }
    }

    /// A thumbnail that will not fit its cap even at the fallback quality is left out rather than sent over it.
    @Test func anOversizeThumbnailIsLeftOut() async throws {
        var limits = ImagePreparer.Limits()
        limits.thumbnailMaxBytes = 10
        let scale = UIGraphicsImageRendererFormat.default().scale

        let data = png(CGSize(width: 800 / scale, height: 600 / scale))
        let draft = try await makePreparer(limits: limits).prepareImage(data, id: "p5")

        #expect(draft.thumbnailURL == nil && draft.thumbnailSizeBytes == nil && draft.uploadRequest.thumbnail == nil)
        #expect(!draft.ref(attachmentID: "x").hasThumbnail)
    }
}
