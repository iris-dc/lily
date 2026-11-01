import ImageIO
import UIKit

/// The one decode of a picture file for a view, at the side the view needs and never at the size the file declares.
/// The bytes reach the device from S3 as the sender put them there, so the header is read first (no pixel decoded) and
/// a picture declaring more pixels than `imageMaxDeclaredPixels` is refused unread: ImageIO downsamples a JPEG or a PNG
/// while reading, but builds a GIF's whole canvas before it can shrink it. What passes is decoded straight to
/// `maxDimension` on its longest side through `downsampled`, the one ImageIO recipe the upload side shares, never
/// upscaled, with the EXIF orientation applied in the pixels. The read and the decode run on a detached task, so neither
/// stalls the main actor.
nonisolated enum ImageFile {
    /// Why a file is not shown as a picture; `notAPicture` covers a missing file too.
    enum Refusal: Error, Equatable, Sendable {
        case notAPicture
        case overThePixelCap(width: Int, height: Int)
    }

    static func load(_ url: URL, maxDimension: Int) async throws -> UIImage {
        try await Task.detached(priority: .userInitiated) { try decoded(url, maxDimension: maxDimension) }.value
    }

    /// The pixel size the file's header declares, read without decoding.
    static func declaredSize(of source: CGImageSource) -> (width: Int, height: Int)? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (width, height)
    }

    /// The source scaled so its longest side is at most `maxDimension`, never upscaled, with the EXIF orientation
    /// applied, so a portrait photo stays portrait; `nil` for bytes ImageIO cannot read as a picture.
    static func downsampled(_ source: CGImageSource, maxDimension: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Whether a header declaring `width` x `height` pixels is within `imageMaxDeclaredPixels`. A header may declare
    /// any 32-bit side, so a product that overflows `Int` is over the cap, never wrapped under it; no side may be empty.
    static func isWithinPixelCap(width: Int, height: Int) -> Bool {
        guard width > 0, height > 0 else { return false }
        let (pixels, overflow) = width.multipliedReportingOverflow(by: height)
        return !overflow && pixels <= AppConfig.Chat.Attachments.imageMaxDeclaredPixels
    }

    private static func decoded(_ url: URL, maxDimension: Int) throws -> UIImage {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              let size = declaredSize(of: source) else { throw Refusal.notAPicture }
        guard isWithinPixelCap(width: size.width, height: size.height) else {
            throw Refusal.overThePixelCap(width: size.width, height: size.height)
        }
        guard let image = downsampled(source, maxDimension: maxDimension) else { throw Refusal.notAPicture }
        return UIImage(cgImage: image)
    }
}
