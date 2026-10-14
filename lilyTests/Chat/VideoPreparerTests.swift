import AVFoundation
import Foundation
import Testing
@testable import lily

/// The preparer over the two-second, 320x180 `tiny.mp4` fixture.
@MainActor
struct VideoPreparerTests {
    private let logger = SpyLogger()
    private let directory = FileManager.default.temporaryDirectory.appending(path: "prepared-\(UUID().uuidString)")

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func makePreparer(limits: VideoPreparer.Limits = VideoPreparer.Limits()) -> VideoPreparer {
        VideoPreparer(limits: limits, directory: directory, logger: logger)
    }

    private func preparedLine(for id: String) -> String? {
        logger.messages(in: .chat, at: .debug).first { $0.hasPrefix("Attachment \(id) prepared:") }
    }

    @Test func aClipIsExportedWithAThumbnailAndItsHints() async throws {
        let draft = try await makePreparer().prepareVideo(at: TestFixtureFiles.tinyVideo, id: "v1", caps: .group)

        #expect(draft.id == "v1" && draft.kind == .video && draft.contentType == "video/mp4" && draft.state == .preparing)
        #expect(draft.fileURL.lastPathComponent == "v1.mp4" && draft.fileURL.path().hasPrefix(directory.path()))
        let written = try Data(contentsOf: draft.fileURL)
        #expect(draft.sizeBytes == written.count && draft.sizeBytes > 0)
        #expect(draft.sizeBytes <= AppConfig.Chat.Attachments.videoMaxBytes)
        #expect(draft.durationSeconds == 2 && draft.width == 320 && draft.height == 180 && draft.fileName == nil)
        let exported = AVURLAsset(url: draft.fileURL)
        let tracks = try await exported.loadTracks(withMediaType: .video)
        #expect(tracks.count == 1, "the export is a playable MP4")
        let thumbnail = try #require(draft.thumbnailURL)
        let size = try ImageFiles.dimensions(of: thumbnail)
        #expect(size.width == 320 && size.height == 180, "the frame keeps its size under the 512 px cap")
        #expect(draft.thumbnailSizeBytes == (try Data(contentsOf: thumbnail)).count)
        #expect(draft.uploadRequest.kind == .video && draft.uploadRequest.durationSeconds == 2)
        #expect(draft.uploadRequest.thumbnail != nil)
        #expect(draft.ref(attachmentID: "x").hasThumbnail)
        #expect(logger.messages(in: .chat, at: .debug).contains("Attachment v1 prepared: \(draft.sizeBytes) B, 2 s video"))
    }

    @Test func aClipLongerThanAllowedIsRefusedBeforeTheExport() async {
        var limits = VideoPreparer.Limits()
        limits.maxDurationSeconds = 1

        await #expect(throws: AppError.attachmentTooLarge(caps: .group)) {
            try await makePreparer(limits: limits).prepareVideo(at: TestFixtureFiles.tinyVideo, id: "v2", caps: .group)
        }
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "v2.mp4").path()))
    }

    /// The cap is the room's, so a conversation's smaller one refuses what a group's would take.
    @Test func anExportOverTheRoomsByteCapIsDeletedAndRefused() async {
        let caps = AttachmentCaps(imageMaxBytes: 10, videoMaxBytes: 10, fileMaxBytes: 10)

        await #expect(throws: AppError.attachmentTooLarge(caps: caps)) {
            try await makePreparer().prepareVideo(at: TestFixtureFiles.tinyVideo, id: "v3", caps: caps)
        }
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "v3.mp4").path()))
    }

    /// The wire takes a video without a thumbnail, so a thumbnail that cannot be written never refuses the clip.
    @Test func aFailedThumbnailStillSendsTheClip() async throws {
        let squatter = directory.appending(path: "v6.thumb.jpg")
        try FileManager.default.createDirectory(at: squatter, withIntermediateDirectories: true)

        let draft = try await makePreparer().prepareVideo(at: TestFixtureFiles.tinyVideo, id: "v6", caps: .group)

        #expect(draft.thumbnailURL == nil && draft.thumbnailSizeBytes == nil && draft.uploadRequest.thumbnail == nil)
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "v6.mp4").path()))
        #expect(draft.durationSeconds == 2)
        #expect(preparedLine(for: "v6")?.hasSuffix("no thumbnail") == true)
    }

    /// A cancelled prepare dies as a cancellation, never as a verdict, and leaves no file behind.
    @Test func removingAVideoMidPrepareCancelsTheExport() async {
        let preparer = makePreparer()
        let task = Task { try await preparer.prepareVideo(at: TestFixtureFiles.tinyVideo, id: "v9", caps: .group) }

        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "v9.mp4").path()))
    }

    /// The backend takes the duration as a positive integer: a clip under half a second is still one second, never zero.
    @Test func theDurationHintIsAPositiveWholeSecond() {
        #expect(VideoEncoding.wholeSeconds(0.3) == 1 && VideoEncoding.wholeSeconds(0) == 1)
        #expect(VideoEncoding.wholeSeconds(2.4) == 2 && VideoEncoding.wholeSeconds(2.6) == 3)
    }

    /// A degenerate track reports a zero size; the hint is left out rather than sent as a zero the backend refuses.
    @Test func aZeroDimensionIsNoHint() {
        #expect(VideoEncoding.positiveDimension(0) == nil && VideoEncoding.positiveDimension(0.4) == nil)
        #expect(VideoEncoding.positiveDimension(1279.6) == 1280)
    }

    @Test func aFileThatIsNoVideoIsRefused() async throws {
        let text = directory.appending(path: "notes.txt")
        try Data("not a video".utf8).write(to: text)

        await #expect(throws: AppError.attachmentTypeNotAllowed) {
            try await makePreparer().prepareVideo(at: text, id: "v4", caps: .group)
        }
    }
}
