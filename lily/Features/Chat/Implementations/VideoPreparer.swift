import AVFoundation
import Foundation

/// Videos for upload: the clip is exported at `videoExportPreset` (720p H.264 in an MP4, so a 4K recording leaves the
/// device at a size the caps allow and every video is `video/mp4`), a frame at `videoThumbnailTime` becomes the
/// thumbnail through the image path, and duration and dimensions ride along as hints. A clip longer than
/// `videoMaxDurationSeconds` is refused before any work; an export over `videoMaxBytes` is deleted and refused. The
/// export runs on AVFoundation's own queues off the main actor; only the draft comes back. One of the three workers
/// behind `DeviceMediaPreparer`.
final class VideoPreparer {
    /// Plain data, free of the actor, so the detached export task and a test's default argument can build one.
    nonisolated struct Limits: Sendable {
        var maxDurationSeconds = AppConfig.Chat.Attachments.videoMaxDurationSeconds
        var exportPreset = AppConfig.Chat.Attachments.videoExportPreset
        var thumbnailTime = AppConfig.Chat.Attachments.videoThumbnailTime
        var thumbnail = ImagePreparer.Limits()
    }

    private let limits: Limits
    private let directory: URL
    private let logger: any Logging

    init(limits: Limits = Limits(), directory: URL = FileManager.default.temporaryDirectory, logger: any Logging) {
        self.limits = limits
        self.directory = directory
        self.logger = logger
    }

    func prepareVideo(at url: URL, id: String, caps: AttachmentCaps) async throws -> AttachmentDraft {
        let limits = self.limits
        let directory = self.directory
        let draft = try await Task.detached(priority: .userInitiated) {
            try await VideoEncoding.prepare(at: url, id: id, limits: limits, caps: caps, in: directory)
        }.value
        logger.debug(.chat, "Attachment \(id) prepared: \(draft.sizeBytes) B, \(draft.durationSeconds ?? 0) s video")
        return draft
    }
}

/// The export work of `VideoPreparer`, free of any actor so it runs on a detached task.
nonisolated enum VideoEncoding {
    static func prepare(at url: URL,
                        id: String,
                        limits: VideoPreparer.Limits,
                        caps: AttachmentCaps,
                        in directory: URL) async throws -> AttachmentDraft {
        let asset = AVURLAsset(url: url)
        let seconds = try await duration(of: asset)
        guard seconds <= limits.maxDurationSeconds else { throw AppError.attachmentTooLarge(caps: caps) }
        let fileURL = directory.appending(path: "\(id).\(AppConfig.Chat.Attachments.videoFileExtension)")
        try await export(asset, to: fileURL, preset: limits.exportPreset)
        let sizeBytes = try fileSize(of: fileURL)
        guard sizeBytes <= caps.videoMaxBytes else {
            try? FileManager.default.removeItem(at: fileURL)
            throw AppError.attachmentTooLarge(caps: caps)
        }
        let exported = AVURLAsset(url: fileURL)
        let size = try await displaySize(of: exported)
        let thumbnail = try await thumbnail(of: exported,
                                            at: min(limits.thumbnailTime, seconds / 2),
                                            id: id,
                                            limits: limits.thumbnail,
                                            in: directory)
        return AttachmentDraft(clientAttachmentID: id,
                               kind: .video,
                               fileURL: fileURL,
                               thumbnailURL: thumbnail?.url,
                               contentType: AppConfig.Chat.Attachments.videoContentType,
                               sizeBytes: sizeBytes,
                               thumbnailSizeBytes: thumbnail?.sizeBytes,
                               width: positiveDimension(size.width),
                               height: positiveDimension(size.height),
                               durationSeconds: wholeSeconds(seconds))
    }

    /// A dimension hint, or none: the backend's `@Positive` refuses a zero, which a degenerate track can report.
    static func positiveDimension(_ points: CGFloat) -> Int? {
        let rounded = Int(points.rounded())
        return rounded > 0 ? rounded : nil
    }

    /// The duration hint as the backend takes it (a positive integer): rounded, and never below one, so a clip shorter
    /// than half a second is not refused by the ticket's `@Positive`.
    static func wholeSeconds(_ seconds: TimeInterval) -> Int {
        max(1, Int(seconds.rounded()))
    }

    /// A file AVFoundation cannot read, or one without a video track, is no video.
    private static func duration(of asset: AVURLAsset) async throws -> TimeInterval {
        guard let duration = try? await asset.load(.duration), duration.isNumeric,
              try await hasVideoTrack(asset) else {
            throw AppError.attachmentTypeNotAllowed
        }
        return duration.seconds
    }

    private static func hasVideoTrack(_ asset: AVURLAsset) async throws -> Bool {
        guard let tracks = try? await asset.loadTracks(withMediaType: .video) else { return false }
        return !tracks.isEmpty
    }

    /// A preset the asset cannot take, or an export that fails, counts as a video the device cannot send.
    private static func export(_ asset: AVURLAsset, to url: URL, preset: String) async throws {
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw AppError.attachmentTypeNotAllowed
        }
        session.shouldOptimizeForNetworkUse = true
        try? FileManager.default.removeItem(at: url)
        do {
            try await session.export(to: url, as: .mp4)
        } catch {
            throw AppError.attachmentTypeNotAllowed
        }
    }

    private static func fileSize(of url: URL) throws -> Int {
        try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    }

    /// The exported track's size with its orientation applied, so a portrait recording is stored portrait.
    private static func displaySize(of asset: AVURLAsset) async throws -> CGSize {
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw AppError.attachmentTypeNotAllowed }
        let (natural, transform) = try await track.load(.naturalSize, .preferredTransform)
        let rect = CGRect(origin: .zero, size: natural).applying(transform)
        return CGSize(width: abs(rect.width), height: abs(rect.height))
    }

    /// The frame at `seconds`, oriented and within the thumbnail's longest side; a clip that yields no frame goes
    /// without a thumbnail rather than not at all.
    private static func thumbnail(of asset: AVURLAsset,
                                  at seconds: TimeInterval,
                                  id: String,
                                  limits: ImagePreparer.Limits,
                                  in directory: URL) async throws -> (url: URL, sizeBytes: Int)? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: limits.thumbnailMaxDimension, height: limits.thumbnailMaxDimension)
        let time = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        guard let frame = try? await generator.image(at: time) else { return nil }
        return try ImageEncoding.writeThumbnail(frame.image, id: id, limits: limits, in: directory)
    }
}
