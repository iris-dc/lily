import AVFoundation
import Foundation

nonisolated extension AppConfig.Chat {
    /// Chat attachments: the caps mirrored from Laurel's `attachments` block (so a draft that passes here is never
    /// refused for its size), how images and videos are re-encoded on the device, how files are taken in, the on-disk
    /// cache and the upload pipeline.
    enum Attachments {
        /// Attachments per message; Laurel's `max-per-message`.
        static let maxPerMessage = 10
        /// A file name longer than this (UTF-16 units, as Bean Validation counts) is a 400; Laurel's `max-file-name-length`.
        static let fileNameMaxLength = 255
        /// An image after the device re-encoded it; Laurel's `image-max-bytes`.
        static let imageMaxBytes = 10 * 1024 * 1024
        /// Longest side of an image after downsampling, in pixels.
        static let imageMaxDimension = 2048
        static let imageJPEGQuality = 0.85
        /// Every image leaves the device as a JPEG (a HEIC or a PNG included), so one type is allowed everywhere.
        static let imageContentType = "image/jpeg"
        /// Longest side of the thumbnail the transcript renders, in pixels; Laurel's `thumbnail-max-bytes` caps its size.
        static let thumbnailMaxDimension = 512
        static let thumbnailMaxBytes = 200 * 1024
        /// A thumbnail over the cap is encoded again at this quality; one still over it is left out.
        static let thumbnailFallbackJPEGQuality = 0.6
        /// The content types Laurel accepts for images and videos; the mock ticket refuses the rest like the backend.
        static let imageContentTypes = ["image/jpeg", "image/png", "image/webp", "image/gif"]
        static let videoContentTypes = ["video/mp4", "video/quicktime"]
        /// A video after the device exported it; Laurel's `video-max-bytes`.
        static let videoMaxBytes = 50 * 1024 * 1024
        /// The longest video the composer takes, in seconds; refused before any export work when over.
        static let videoMaxDurationSeconds: TimeInterval = 180
        /// Every video leaves the device at this preset: 720p H.264 in an MP4, so a 4K recording fits the caps.
        static let videoExportPreset = AVAssetExportPreset1280x720
        static let videoContentType = "video/mp4"
        static let videoFileExtension = "mp4"
        /// Where in a video the thumbnail frame is taken, in seconds; clamped into a shorter clip.
        static let videoThumbnailTime: TimeInterval = 0.5
        /// Any other file; Laurel's `file-max-bytes`.
        static let fileMaxBytes = 25 * 1024 * 1024
        /// The video and file caps in a direct conversation (`AttachmentCaps.direct`); Laurel's `direct-video-max-bytes`
        /// and `direct-file-max-bytes`. Pictures keep `imageMaxBytes` there.
        static let directVideoMaxBytes = 20 * 1024 * 1024
        static let directFileMaxBytes = 5 * 1024 * 1024
        /// What a file is declared as when the system cannot name its type.
        static let fallbackFileContentType = "application/octet-stream"
        /// Bytes the on-disk cache keeps; the least recently used files go first.
        static let diskCacheBytes = 200 * 1024 * 1024
        /// A presigned link this close to its expiry is refreshed before the download.
        static let urlRefreshMargin: TimeInterval = 60
        static let maxConcurrentUploads = 2
        /// How long one PUT may take; a foreground session, so backgrounding mid-upload fails the attachment.
        static let uploadTimeout: TimeInterval = 120
        /// The mock uploader spreads its progress over this long, in `mockUploadSteps` steps.
        static let mockUploadDelay: Duration = .milliseconds(600)
        static let mockUploadSteps = 4
        /// How long the mock's presigned links and tickets live.
        static let mockLinkTTL: TimeInterval = 3600
        static let mockUploadTicketTTL: TimeInterval = 900
        /// Scheme and host of the mock's presigned URLs; `MockAttachmentURLProtocol` answers them from the mock store.
        static let mockURLScheme = "mock"
        static let mockURLHost = "attachments"
        /// The data sets in `Assets.xcassets` the mock picker hands over as the picked photo, the recorded clip and the
        /// picked file, and the names the clip and the file get on the device.
        static let mockPhotoAssetName = "MockAttachmentPhoto"
        static let mockVideoAssetName = "MockAttachmentVideo"
        static let mockFileAssetName = "MockAttachmentFile"
        static let mockVideoFileName = "clip.mp4"
        static let mockFileName = "training-plan.pdf"
        /// Under the temporary directory: a cached file is given its name and extension back here for QuickLook.
        static let previewDirectoryName = "AttachmentPreviews"
        /// The cache directory under `Caches/`, and how a thumbnail's file is told from the full object's.
        static let cacheDirectoryName = "Attachments"
        static let thumbnailFileSuffix = ".thumb"
        /// The files a prepared image is written to, next to each other in the temporary directory.
        static let preparedFileExtension = "jpg"
        /// The status a presigned link answers once its signature expired; the loader refreshes the link once on it.
        static let forbiddenStatus = 403
    }
}

nonisolated extension AppConfig.API.Paths {
    /// `POST` asks for a presigned upload ticket for one attachment of a message about to be sent in the group.
    static func uploads(id: String) -> String {
        "\(group(id: id))/uploads"
    }

    /// `GET` answers fresh presigned links for an attachment; the message id is in the path because the caller's
    /// history floor is checked against the message.
    static func attachment(id: String, messageID: String, attachmentID: String) -> String {
        "\(message(id: id, messageID: messageID))/attachments/\(attachmentID)"
    }
}

nonisolated extension AppConfig.LaunchArguments {
    /// Makes "Photo library" add the bundled `MockAttachmentPhoto` at once instead of opening the system picker, which
    /// XCUITest cannot drive (it runs out of process); the UI tests pass it with `-mock-events`.
    static let mockAttachmentPicker = "-mock-attachment-picker"
}
