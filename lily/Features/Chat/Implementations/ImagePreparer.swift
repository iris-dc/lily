import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Pictures for upload: `CGImageSource` downsamples to `imageMaxDimension` without decoding the full bitmap (a 48 MP
/// HEIC never lands in memory whole), the result is written as a JPEG at `imageJPEGQuality` (so every picture leaves
/// the device as `image/jpeg`, whatever the camera shot), and a `thumbnailMaxDimension` thumbnail goes with it. The
/// work runs off the main actor; only the draft comes back. One of the three workers behind `DeviceMediaPreparer`.
final class ImagePreparer {
    /// Plain data, free of the actor, so the detached encoding task and a test's default argument can build one.
    nonisolated struct Limits: Sendable {
        var maxBytes = AppConfig.Chat.Attachments.imageMaxBytes
        var maxDimension = AppConfig.Chat.Attachments.imageMaxDimension
        var jpegQuality = AppConfig.Chat.Attachments.imageJPEGQuality
        var thumbnailMaxDimension = AppConfig.Chat.Attachments.thumbnailMaxDimension
        var thumbnailMaxBytes = AppConfig.Chat.Attachments.thumbnailMaxBytes
        var thumbnailFallbackQuality = AppConfig.Chat.Attachments.thumbnailFallbackJPEGQuality
    }

    private let limits: Limits
    private let directory: URL
    private let logger: any Logging

    init(limits: Limits = Limits(), directory: URL = FileManager.default.temporaryDirectory, logger: any Logging) {
        self.limits = limits
        self.directory = directory
        self.logger = logger
    }

    func prepareImage(_ data: Data, id: String) async throws -> AttachmentDraft {
        let limits = self.limits
        let directory = self.directory
        let draft = try await Task.detached(priority: .userInitiated) {
            try ImageEncoding.prepare(data, id: id, limits: limits, in: directory)
        }.value
        logger.debug(.chat, "Attachment \(id) prepared: \(draft.sizeBytes) B, \(draft.width ?? 0)x\(draft.height ?? 0)")
        return draft
    }
}

/// The CPU work of `ImagePreparer`, free of any actor so it runs on a detached task.
nonisolated enum ImageEncoding {
    static func prepare(_ data: Data, id: String, limits: ImagePreparer.Limits, in directory: URL) throws -> AttachmentDraft {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else {
            throw AppError.attachmentTypeNotAllowed
        }
        let image = try downsample(source, maxDimension: limits.maxDimension)
        let jpeg = try jpegData(image, quality: limits.jpegQuality)
        guard jpeg.count <= limits.maxBytes else { throw AppError.attachmentTooLarge }
        let fileURL = try write(jpeg, id: id, suffix: "", in: directory)
        let thumbnail = try writeThumbnail(try downsample(source, maxDimension: limits.thumbnailMaxDimension),
                                           id: id,
                                           limits: limits,
                                           in: directory)
        return AttachmentDraft(clientAttachmentID: id,
                               kind: .image,
                               fileURL: fileURL,
                               thumbnailURL: thumbnail?.url,
                               contentType: AppConfig.Chat.Attachments.imageContentType,
                               sizeBytes: jpeg.count,
                               thumbnailSizeBytes: thumbnail?.sizeBytes,
                               width: image.width,
                               height: image.height)
    }

    /// A frame already within `thumbnailMaxDimension` (a downsampled picture, a video's frame) as the thumbnail file
    /// next to the other prepared files: encoded again at the fallback quality when over its byte cap, and left out
    /// (`nil`) when still over it, so the transcript renders the full object instead.
    static func writeThumbnail(_ image: CGImage,
                               id: String,
                               limits: ImagePreparer.Limits,
                               in directory: URL) throws -> (url: URL, sizeBytes: Int)? {
        guard let data = try thumbnailData(image, limits: limits) else { return nil }
        return (try write(data, id: id, suffix: AppConfig.Chat.Attachments.thumbnailFileSuffix, in: directory), data.count)
    }

    private static func thumbnailData(_ image: CGImage, limits: ImagePreparer.Limits) throws -> Data? {
        let data = try jpegData(image, quality: limits.jpegQuality)
        if data.count <= limits.thumbnailMaxBytes { return data }
        let smaller = try jpegData(image, quality: limits.thumbnailFallbackQuality)
        return smaller.count <= limits.thumbnailMaxBytes ? smaller : nil
    }

    /// `<id><suffix>.jpg` in `directory`.
    private static func write(_ data: Data, id: String, suffix: String, in directory: URL) throws -> URL {
        let url = directory.appending(path: "\(id)\(suffix).\(AppConfig.Chat.Attachments.preparedFileExtension)")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// The source scaled so its longest side is at most `maxDimension`, never upscaled, with the EXIF orientation
    /// applied, so a portrait photo stays portrait.
    private static func downsample(_ source: CGImageSource, maxDimension: Int) throws -> CGImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw AppError.attachmentTypeNotAllowed
        }
        return image
    }

    private static func jpegData(_ image: CGImage, quality: Double) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw AppError.attachmentTypeNotAllowed
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw AppError.attachmentTypeNotAllowed }
        return data as Data
    }
}
