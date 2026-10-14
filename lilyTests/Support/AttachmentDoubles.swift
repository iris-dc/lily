import Foundation
@testable import lily

/// Records every upload and answers at once, or after `releaseRequests()` while `holdsRequests`; `errors` are thrown
/// one per upload, `error` by every one. Reports half-way progress before the hold and full progress after.
@MainActor
final class FakeAttachmentUploader: AttachmentUploader, HoldsRequests {
    var error: (any Error)?
    var errors: [any Error] = []
    let hold = RequestHold()
    private(set) var uploads: [(draft: AttachmentDraft, ticket: UploadTicket)] = []
    /// Uploads started and not yet answered.
    private(set) var inFlight = 0

    func upload(_ draft: AttachmentDraft,
                with ticket: UploadTicket,
                progress: @escaping @MainActor (Double) -> Void) async throws {
        uploads.append((draft, ticket))
        inFlight += 1
        defer { inFlight -= 1 }
        progress(0.5)
        try await hold.waitOrThrow()
        if !errors.isEmpty { throw errors.removeFirst() }
        if let error { throw error }
        progress(1)
    }
}

/// Prepares by writing the picked bytes to a file of their own (and a small thumbnail next to it), so the drafts it
/// answers have real files to copy and read; a video or a file is answered over a copy of its own in tmp (`<id>.mp4`
/// with a thumbnail, `<id>.<ext>`), as the real preparers do, because the composer removes a picked movie once the
/// preparer is done with it. `error` refuses everything; `photo`, `video` and `file` are what the mock picker hands over.
/// Like the real preparers' detached work, a prepare of any kind cancelled while held still delivers its files, so the
/// model's handling of a late answer for a removed slot can be tested.
@MainActor
final class FakeMediaPreparer: MediaPreparer, HoldsRequests {
    var error: (any Error)?
    var photo: Data?
    var video: URL?
    var file: URL?
    let hold = RequestHold()
    private(set) var preparedIDs: [String] = []
    private(set) var preparedVideoURLs: [URL] = []
    private(set) var preparedFileURLs: [URL] = []
    /// The room's caps each prepare was given, in order.
    private(set) var preparedCaps: [AttachmentCaps] = []

    func prepareImage(_ data: Data, id: String, caps: AttachmentCaps) async throws -> AttachmentDraft {
        preparedIDs.append(id)
        preparedCaps.append(caps)
        await hold.wait()
        if let error { throw error }
        return try AttachmentDraft.prepared(id: id, data: data)
    }

    func prepareVideo(at url: URL, id: String, caps: AttachmentCaps) async throws -> AttachmentDraft {
        preparedIDs.append(id)
        preparedVideoURLs.append(url)
        preparedCaps.append(caps)
        await hold.wait()
        if let error { throw error }
        let draft = AttachmentDraft.fixture(id: id, kind: .video, fileURL: try Self.copy(url, to: "\(id).mp4"), state: .preparing)
        if let thumbnailURL = draft.thumbnailURL { try Data("thumb".utf8).write(to: thumbnailURL) }
        return draft
    }

    func prepareFile(at url: URL, id: String, caps: AttachmentCaps) async throws -> AttachmentDraft {
        preparedIDs.append(id)
        preparedFileURLs.append(url)
        preparedCaps.append(caps)
        await hold.wait()
        if let error { throw error }
        let own = try Self.copy(url, to: url.pathExtension.isEmpty ? id : "\(id).\(url.pathExtension)")
        return .fixture(id: id, kind: .file, fileURL: own, fileName: url.lastPathComponent, state: .preparing)
    }

    /// The source's bytes (a few stand-in bytes when no file is behind the URL) written under `name` in tmp: the file
    /// of the draft's own that the real preparers leave.
    private static func copy(_ url: URL, to name: String) throws -> URL {
        let own = FileManager.default.temporaryDirectory.appending(path: name)
        try ((try? Data(contentsOf: url)) ?? Data("clip".utf8)).write(to: own)
        return own
    }

    func photoWithoutPicker() -> Data? { photo }

    func videoWithoutPicker() -> URL? { video }

    func fileWithoutPicker() -> URL? { file }
}

/// An attachment cache in memory: downloaded bytes go to a file in a directory of the instance's own (removed by
/// `clear()`), copies are recorded and answered as the source itself (nothing is copied), `evict()` has nothing to do,
/// and a `storeError` is what both stores refuse with (a full disk), before anything is written or recorded.
@MainActor
final class FakeAttachmentCache: AttachmentCache {
    struct Copy: Equatable {
        let id: String
        let variant: AttachmentVariant
        let source: URL
    }

    var storeError: (any Error)?
    private let directory = FileManager.default.temporaryDirectory
        .appending(path: "fake-cache-\(UUID().uuidString)", directoryHint: .isDirectory)
    private var files: [String: URL] = [:]
    private(set) var copied: [Copy] = []

    func fileURL(for id: String, variant: AttachmentVariant) -> URL? {
        files[id + variant.fileSuffix]
    }

    @discardableResult
    func store(_ data: Data, for id: String, variant: AttachmentVariant) async throws -> URL {
        if let storeError { throw storeError }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: UUID().uuidString)
        try data.write(to: url)
        files[id + variant.fileSuffix] = url
        return url
    }

    @discardableResult
    func store(copying fileURL: URL, for id: String, variant: AttachmentVariant) async throws -> URL {
        if let storeError { throw storeError }
        copied.append(Copy(id: id, variant: variant, source: fileURL))
        files[id + variant.fileSuffix] = fileURL
        return fileURL
    }

    func evict() async {}

    func clear() async {
        files = [:]
        try? FileManager.default.removeItem(at: directory)
    }
}

extension AttachmentDraft {
    /// A draft without files on disk, for the model tests; `state` says where it stands. A picture by default; a video
    /// carries a thumbnail and a duration, a file its name and no thumbnail, and anything that is no picture or video
    /// takes the file shape. With a `fileURL` the thumbnail sits next to it as `<name>.thumb.jpg`, so a test that
    /// writes both can.
    static func fixture(id: String = "d1",
                        kind: AttachmentKind = .image,
                        fileURL: URL? = nil,
                        fileName: String? = nil,
                        state: State = .uploaded(.fixture())) -> AttachmentDraft {
        let thumbnailURL = fileURL.map { $0.deletingPathExtension().appendingPathExtension("thumb.jpg") }
            ?? URL(fileURLWithPath: "/tmp/\(id).thumb.jpg")
        return if kind == .video {
            AttachmentDraft(clientAttachmentID: id,
                            kind: .video,
                            fileURL: fileURL ?? URL(fileURLWithPath: "/tmp/\(id).mp4"),
                            thumbnailURL: thumbnailURL,
                            contentType: "video/mp4",
                            sizeBytes: 5_242_880,
                            thumbnailSizeBytes: 30_000,
                            width: 1280,
                            height: 720,
                            durationSeconds: 12,
                            state: state)
        } else if kind.isMedia {
            AttachmentDraft(clientAttachmentID: id,
                            kind: .image,
                            fileURL: fileURL ?? URL(fileURLWithPath: "/tmp/\(id).jpg"),
                            thumbnailURL: thumbnailURL,
                            contentType: "image/jpeg",
                            sizeBytes: 812_345,
                            thumbnailSizeBytes: 41_230,
                            width: 2048,
                            height: 1536,
                            state: state)
        } else {
            AttachmentDraft(clientAttachmentID: id,
                            kind: .file,
                            fileURL: fileURL ?? URL(fileURLWithPath: "/tmp/\(id).pdf"),
                            contentType: "application/pdf",
                            sizeBytes: 19_358,
                            fileName: fileName ?? "training-plan.pdf",
                            state: state)
        }
    }

    /// A draft whose file holds `data` and whose thumbnail holds a few bytes, both written now.
    static func prepared(id: String, data: Data) throws -> AttachmentDraft {
        let directory = FileManager.default.temporaryDirectory
        let fileURL = directory.appending(path: "\(id).jpg")
        let thumbnailURL = directory.appending(path: "\(id).thumb.jpg")
        try data.write(to: fileURL)
        try Data("thumb".utf8).write(to: thumbnailURL)
        return AttachmentDraft(clientAttachmentID: id,
                               kind: .image,
                               fileURL: fileURL,
                               thumbnailURL: thumbnailURL,
                               contentType: "image/jpeg",
                               sizeBytes: data.count,
                               thumbnailSizeBytes: 5,
                               width: 2048,
                               height: 1536)
    }
}

extension AttachmentRef {
    static func fixture(attachmentID: String = "att-1", hasThumbnail: Bool = true) -> AttachmentRef {
        AttachmentRef(attachmentId: attachmentID,
                      kind: .image,
                      contentType: "image/jpeg",
                      sizeBytes: 812_345,
                      width: 2048,
                      height: 1536,
                      hasThumbnail: hasThumbnail)
    }
}

/// The attachment JSON exactly as Laurel's `AttachmentControllerIt` / `ChatControllerIt` pin it (B-C hand-over).
extension ContractSamples {
    static let attachment = """
    {"id":"01ARYZ6S41TSV4RRFFQ69G5FB0","kind":"image","contentType":"image/jpeg","sizeBytes":812345,"width":2048,"height":1536,\
    "url":"https://lily-chat.s3.eu-central-1.amazonaws.com/chat/g1/01ARYZ6S41TSV4RRFFQ69G5FB0?X-Amz-Signature=main",\
    "thumbnailUrl":"https://lily-chat.s3.eu-central-1.amazonaws.com/chat/g1/01ARYZ6S41TSV4RRFFQ69G5FB0/thumb?X-Amz-Signature=thumb",\
    "urlExpiresAt":"2026-09-25T11:00:00Z"}
    """
    /// `201` of a send that is its picture alone (`ChatControllerIt.send_acceptsAttachmentsOnly`): no `text`.
    static let imageMessage = """
    {"id":"01ARYZ6S41TSV4RRFFQ69G5FAV","groupId":"g1","senderUserId":"sub-1","senderName":"Marta","kind":"text",\
    "clientMessageId":"9b2f6c1e-3d4a-4f5b-8c6d-7e8f9a0b1c2d","sentAt":"2026-09-25T10:00:00Z","isDeleted":false,\
    "attachments":[\(attachment)]}
    """
    static let imageSentMessage = #"{"message":\#(imageMessage),"channelEpoch":3}"#
    /// `201` of `POST /api/groups/{id}/uploads` (`AttachmentControllerIt.requestUpload_takesTokenAdmitsAndAnswers201`).
    static let uploadTicket = """
    {"attachmentId":"01ARYZ6S41TSV4RRFFQ69G5FB0",\
    "upload":{"url":"https://lily-chat.s3.eu-central-1.amazonaws.com/chat/g1/01ARYZ6S41TSV4RRFFQ69G5FB0?X-Amz-Signature=main",\
    "headers":{"Content-Type":"image/jpeg","Content-Length":"812345","x-amz-meta-uploader":"sub-1"}},\
    "thumbnailUpload":{"url":"https://lily-chat.s3.eu-central-1.amazonaws.com/chat/g1/01ARYZ6S41TSV4RRFFQ69G5FB0/thumb?X-Amz-Signature=thumb",\
    "headers":{"Content-Type":"image/jpeg","Content-Length":"41230","x-amz-meta-uploader":"sub-1"}},\
    "expiresAt":"2026-09-25T10:15:00Z"}
    """
    /// `200` of the link route (`AttachmentControllerIt.link_answersFreshUrls`).
    static let attachmentLink = """
    {"url":"https://lily-chat.s3.eu-central-1.amazonaws.com/chat/g1/01ARYZ6S41TSV4RRFFQ69G5FB0?X-Amz-Signature=main",\
    "thumbnailUrl":"https://lily-chat.s3.eu-central-1.amazonaws.com/chat/g1/01ARYZ6S41TSV4RRFFQ69G5FB0/thumb?X-Amz-Signature=thumb",\
    "urlExpiresAt":"2026-09-25T11:00:00Z"}
    """
}

extension CGFloat? {
    /// Equal within a hair, for aspect ratios: `2048 / 1536` and `4 / 3` need not share every bit.
    func isAbout(_ value: CGFloat) -> Bool {
        guard let self else { return false }
        return abs(self - value) < 0.0001
    }
}
