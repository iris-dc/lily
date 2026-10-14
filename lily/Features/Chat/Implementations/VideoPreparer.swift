import AVFoundation
import Foundation

/// Videos for upload: the clip is exported at `videoExportPreset` (720p H.264 in an MP4, so a 4K recording leaves the
/// device at a size the caps allow and every video is `video/mp4`), a frame at `videoThumbnailTime` becomes the
/// thumbnail through the image path when one can be made (the API takes a draft without one), and duration and
/// dimensions ride along as hints. A clip longer than `videoMaxDurationSeconds` is refused before any work; an export
/// over `videoMaxBytes`, or any step that fails after the export, deletes the file before it refuses, so no clip stays
/// in tmp. The export runs on AVFoundation's own queues off the main actor and dies with the caller (`DetachedWork`);
/// only the draft comes back. One of the three workers behind `DeviceMediaPreparer`.
final class VideoPreparer {
    /// Plain data, free of the actor, so the detached export task can take one.
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
        let draft = try await DetachedWork.run {
            try await VideoEncoding.prepare(at: url, id: id, limits: limits, caps: caps, in: directory)
        }
        let note = ImageEncoding.thumbnailNote(for: draft)
        logger.debug(.chat, "Attachment \(id) prepared: \(draft.sizeBytes) B, \(draft.durationSeconds ?? 0) s video\(note)")
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
        try Task.checkCancellation()
        let asset = AVURLAsset(url: url)
        let seconds = try await duration(of: asset)
        try Task.checkCancellation()
        guard seconds <= limits.maxDurationSeconds else { throw AppError.attachmentTooLarge(caps: caps) }
        let fileURL = directory.appending(path: "\(id).\(AppConfig.Chat.Attachments.videoFileExtension)")
        try await export(asset, to: fileURL, preset: limits.exportPreset)
        return try await finish(fileURL: fileURL, seconds: seconds, id: id, limits: limits, caps: caps)
    }

    /// Everything after the export, with the export's fate tied to it: a step that fails here (the byte cap, a track
    /// without a size, a cancellation) deletes the file before the error leaves, so neither a refused nor an abandoned
    /// clip stays in tmp. The thumbnail goes next to the export and cannot fail the clip: a frame that cannot be made
    /// or written is left out.
    private static func finish(fileURL: URL,
                               seconds: TimeInterval,
                               id: String,
                               limits: VideoPreparer.Limits,
                               caps: AttachmentCaps) async throws -> AttachmentDraft {
        do {
            let sizeBytes = try fileSize(of: fileURL)
            try caps.require(sizeBytes: sizeBytes, for: .video)
            let exported = AVURLAsset(url: fileURL)
            let size = try await displaySize(of: exported)
            try Task.checkCancellation()
            let thumbnail = await thumbnail(of: exported,
                                            at: min(limits.thumbnailTime, seconds / 2),
                                            id: id,
                                            limits: limits.thumbnail,
                                            in: fileURL.deletingLastPathComponent())
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
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            throw error
        }
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

    /// A file AVFoundation cannot read, or one without a video track, is no video; a load the caller cancelled is not.
    private static func duration(of asset: AVURLAsset) async throws -> TimeInterval {
        guard let duration = try? await asset.load(.duration), duration.isNumeric,
              try await hasVideoTrack(asset) else {
            try Task.checkCancellation()
            throw AppError.attachmentTypeNotAllowed
        }
        return duration.seconds
    }

    private static func hasVideoTrack(_ asset: AVURLAsset) async throws -> Bool {
        guard let tracks = try? await asset.loadTracks(withMediaType: .video) else { return false }
        return !tracks.isEmpty
    }

    /// A preset the asset cannot take, or an export that fails, counts as a video the device cannot send; an export the
    /// caller cancelled is a cancellation. Neither leaves the partial file the session may have written.
    private static func export(_ asset: AVURLAsset, to url: URL, preset: String) async throws {
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw AppError.attachmentTypeNotAllowed
        }
        session.shouldOptimizeForNetworkUse = true
        try? FileManager.default.removeItem(at: url)
        do {
            try await session.export(to: url, as: .mp4)
        } catch {
            try? FileManager.default.removeItem(at: url)
            try Task.checkCancellation()
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

    /// The frame at `seconds`, oriented and within the thumbnail's longest side, as the thumbnail file; a clip that
    /// yields no frame, or a frame that cannot be written, goes without a thumbnail rather than not at all.
    private static func thumbnail(of asset: AVURLAsset,
                                  at seconds: TimeInterval,
                                  id: String,
                                  limits: ImagePreparer.Limits,
                                  in directory: URL) async -> (url: URL, sizeBytes: Int)? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: limits.thumbnailMaxDimension, height: limits.thumbnailMaxDimension)
        let time = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        guard let frame = try? await generator.image(at: time) else { return nil }
        return try? ImageEncoding.writeThumbnail(frame.image, id: id, limits: limits, in: directory)
    }
}
