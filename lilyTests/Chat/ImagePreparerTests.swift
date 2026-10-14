import Foundation
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import lily

/// Pictures through the preparer: a big PNG leaves as an upright JPEG within the longest side with a thumbnail under its
/// cap, both as files; too many bytes or no picture is refused; a thumbnail that cannot be made never refuses the picture.
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
            drawGradient(in: context.cgContext, to: size)
        }
    }

    /// A JPEG of `size` carrying an EXIF orientation, as a camera writes one: the pixels stay as rendered and the tag
    /// says how to turn them.
    private func jpeg(_ size: CGSize, orientation: Int) throws -> Data {
        let image = UIGraphicsImageRenderer(size: size, format: UIGraphicsImageRendererFormat.default()).image { context in
            drawGradient(in: context.cgContext, to: size)
        }
        let cgImage = try #require(image.cgImage)
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, cgImage, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func drawGradient(in context: CGContext, to size: CGSize) {
        let colors = [UIColor.systemRed.cgColor, UIColor.systemBlue.cgColor] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil)!
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
    }

    private func preparedLine(for id: String) -> String? {
        logger.messages(in: .chat, at: .debug).first { $0.hasPrefix("Attachment \(id) prepared:") }
    }

    @Test func aLargePNGBecomesAJPEGWithinTheLongestSide() async throws {
        let format = UIGraphicsImageRendererFormat.default()
        let scale = format.scale
        let data = png(CGSize(width: 4000 / scale, height: 3000 / scale))

        let draft = try await makePreparer().prepareImage(data, id: "p1", caps: .group)

        #expect(draft.id == "p1" && draft.kind == .image && draft.contentType == "image/jpeg" && draft.state == .preparing)
        #expect(draft.width == 2048 && draft.height == 1536)
        #expect(try ImageFiles.dimensions(of: draft.fileURL) == (2048, 1536))
        let written = try Data(contentsOf: draft.fileURL)
        #expect(draft.sizeBytes == written.count && draft.sizeBytes > 0)
        #expect(draft.fileURL.lastPathComponent == "p1.jpg" && draft.fileURL.path().hasPrefix(directory.path()))
        let thumbnail = try #require(draft.thumbnailURL)
        let thumbnailSize = try ImageFiles.dimensions(of: thumbnail)
        #expect(thumbnailSize.width == 512 && thumbnailSize.height == 384)
        let thumbnailBytes = try Data(contentsOf: thumbnail)
        #expect(draft.thumbnailSizeBytes == thumbnailBytes.count)
        #expect(draft.thumbnailSizeBytes.map { $0 <= AppConfig.Chat.Attachments.thumbnailMaxBytes } == true)
        #expect(logger.messages(in: .chat, at: .debug).contains("Attachment p1 prepared: \(draft.sizeBytes) B, 2048x1536"))
    }

    /// A picture already within the longest side keeps its size.
    @Test func aSmallPictureIsNotUpscaled() async throws {
        let scale = UIGraphicsImageRendererFormat.default().scale
        let small = png(CGSize(width: 300 / scale, height: 200 / scale))
        let draft = try await makePreparer().prepareImage(small, id: "p2", caps: .group)
        #expect(draft.width == 300 && draft.height == 200)
    }

    /// A camera stores a portrait shot as landscape pixels plus an orientation tag; the picture leaves upright with the
    /// tag applied, so whoever ignores EXIF (a browser, the backend's thumbnail) still sees it the right way up.
    @Test func anEXIFRotatedPictureComesOutUpright() async throws {
        let scale = UIGraphicsImageRendererFormat.default().scale
        let data = try jpeg(CGSize(width: 600 / scale, height: 400 / scale), orientation: 6)

        let draft = try await makePreparer().prepareImage(data, id: "p9", caps: .group)

        #expect(draft.width == 400 && draft.height == 600)
        #expect(try ImageFiles.dimensions(of: draft.fileURL) == (400, 600))
        let thumbnail = try ImageFiles.dimensions(of: try #require(draft.thumbnailURL))
        #expect(thumbnail.width < thumbnail.height, "the thumbnail is turned with the picture")
    }

    /// The cap is the room's, so the refusal names the room's caps for the popup.
    @Test func aPictureOverTheRoomsByteCapIsRefused() async {
        let caps = AttachmentCaps(imageMaxBytes: 10, videoMaxBytes: 10, fileMaxBytes: 10)
        let scale = UIGraphicsImageRendererFormat.default().scale
        let data = png(CGSize(width: 800 / scale, height: 600 / scale))

        await #expect(throws: AppError.attachmentTooLarge(caps: caps)) {
            try await makePreparer().prepareImage(data, id: "p3", caps: caps)
        }
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "p3.jpg").path()))
    }

    @Test func bytesThatAreNoPictureAreRefused() async {
        await #expect(throws: AppError.attachmentTypeNotAllowed) {
            try await makePreparer().prepareImage(Data("not an image".utf8), id: "p4", caps: .group)
        }
    }

    /// A thumbnail that will not fit its cap even at the fallback quality is left out rather than sent over it.
    @Test func anOversizeThumbnailIsLeftOut() async throws {
        var limits = ImagePreparer.Limits()
        limits.thumbnailMaxBytes = 10
        let scale = UIGraphicsImageRendererFormat.default().scale

        let data = png(CGSize(width: 800 / scale, height: 600 / scale))
        let draft = try await makePreparer(limits: limits).prepareImage(data, id: "p5", caps: .group)

        #expect(draft.thumbnailURL == nil && draft.thumbnailSizeBytes == nil && draft.uploadRequest.thumbnail == nil)
        #expect(!draft.ref(attachmentID: "x").hasThumbnail)
    }

    /// Over its cap at the picture's quality, a thumbnail is encoded again at the fallback quality; one that fits neither is left out.
    @Test func aThumbnailOverTheCapIsReencodedAtTheFallbackQuality() async throws {
        let scale = UIGraphicsImageRendererFormat.default().scale
        let data = png(CGSize(width: 1600 / scale, height: 1200 / scale))
        let atPictureQuality = try await makePreparer().prepareImage(data, id: "p7", caps: .group)
        let size = try #require(atPictureQuality.thumbnailSizeBytes)
        var limits = ImagePreparer.Limits()
        limits.thumbnailMaxBytes = size - 1

        let draft = try await makePreparer(limits: limits).prepareImage(data, id: "p8", caps: .group)

        #expect(draft.thumbnailURL != nil)
        let reencoded = try #require(draft.thumbnailSizeBytes)
        #expect(reencoded < size, "the fallback quality brings it under the cap")
    }

    /// The API takes a draft without a thumbnail, so a thumbnail that cannot be written leaves the picture to go alone
    /// rather than refusing it; the debug line says what is missing.
    @Test func aFailedThumbnailStillSendsThePicture() async throws {
        let squatter = directory.appending(path: "p6.thumb.jpg")
        try FileManager.default.createDirectory(at: squatter, withIntermediateDirectories: true)
        let scale = UIGraphicsImageRendererFormat.default().scale
        let data = png(CGSize(width: 800 / scale, height: 600 / scale))

        let draft = try await makePreparer().prepareImage(data, id: "p6", caps: .group)

        #expect(draft.thumbnailURL == nil && draft.thumbnailSizeBytes == nil && draft.uploadRequest.thumbnail == nil)
        #expect(!draft.ref(attachmentID: "x").hasThumbnail)
        #expect(FileManager.default.fileExists(atPath: draft.fileURL.path()) && draft.sizeBytes > 0)
        #expect(preparedLine(for: "p6")?.hasSuffix("no thumbnail") == true)
    }
}
