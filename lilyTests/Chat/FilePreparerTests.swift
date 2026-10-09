import Foundation
import Testing
import UniformTypeIdentifiers
@testable import lily

/// Files through the preparer: copied under the draft's id with their extension, typed from what the system knows,
/// named after themselves (cut to the backend's limit), refused when over the cap or when no file at all.
@MainActor
struct FilePreparerTests {
    private let logger = SpyLogger()
    private let directory = FileManager.default.temporaryDirectory.appending(path: "prepared-\(UUID().uuidString)")
    private let picked = FileManager.default.temporaryDirectory.appending(path: "picked-\(UUID().uuidString)")

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: picked, withIntermediateDirectories: true)
    }

    private func makePreparer() -> FilePreparer {
        FilePreparer(directory: directory, logger: logger)
    }

    private func file(named name: String, bytes: Int = 64) throws -> URL {
        let url = picked.appending(path: name)
        try Data(repeating: 9, count: bytes).write(to: url)
        return url
    }

    @Test func aFileIsCopiedTypedAndNamed() async throws {
        let notes = try file(named: "notes.txt")

        let draft = try await makePreparer().prepareFile(at: notes, id: "f1", caps: .group)

        #expect(draft.id == "f1" && draft.kind == .file && draft.contentType == "text/plain" && draft.state == .preparing)
        #expect(draft.fileName == "notes.txt" && draft.sizeBytes == 64 && draft.thumbnailURL == nil)
        #expect(draft.fileURL == directory.appending(path: "f1.txt"))
        #expect(try Data(contentsOf: draft.fileURL) == Data(repeating: 9, count: 64), "the copy holds the bytes")
        #expect(FileManager.default.fileExists(atPath: notes.path()), "the original is left where it was")
        #expect(draft.uploadRequest.thumbnail == nil && draft.uploadRequest.fileName == "notes.txt")
        #expect(!draft.ref(attachmentID: "x").hasThumbnail)
        #expect(logger.messages(in: .chat, at: .debug).contains("Attachment f1 prepared: 64 B file of type text/plain"))
    }

    @Test func anUnknownTypeIsAnOctetStreamAndKeepsNoExtension() async throws {
        let odd = try file(named: "export.xyz123")
        let draft = try await makePreparer().prepareFile(at: odd, id: "f2", caps: .group)
        #expect(draft.contentType == "application/octet-stream" && draft.fileURL.lastPathComponent == "f2.xyz123")

        let bare = try file(named: "README")
        let bareDraft = try await makePreparer().prepareFile(at: bare, id: "f3", caps: .group)
        #expect(bareDraft.fileURL.lastPathComponent == "f3" && bareDraft.fileName == "README")
        #expect(!bareDraft.contentType.isEmpty, "the system types an extension-less file as it likes")

        #expect(FileCopying.contentType(nil, extension: "") == "application/octet-stream")
        #expect(FileCopying.contentType(nil, extension: "xyz123") == "application/octet-stream")
        #expect(FileCopying.contentType(nil, extension: "pdf") == "application/pdf")
        #expect(FileCopying.contentType(.plainText, extension: "pdf") == "text/plain", "the file's own type wins")
    }

    /// The file system itself allows no longer name, so the cut a provider's name could need is the draft's.
    @Test func aNameAtTheLimitIsKeptWholeAndALongerOneIsCut() async throws {
        let limit = AppConfig.Chat.Attachments.fileNameMaxLength
        let name = String(repeating: "a", count: limit - 4) + ".pdf"
        let draft = try await makePreparer().prepareFile(at: try file(named: name), id: "f4", caps: .group)

        #expect(draft.fileName == name && draft.fileName?.wireLength == limit && draft.contentType == "application/pdf")
        let longer = AttachmentDraft(clientAttachmentID: "f4",
                                     kind: .file,
                                     fileURL: draft.fileURL,
                                     contentType: draft.contentType,
                                     sizeBytes: draft.sizeBytes,
                                     fileName: String(repeating: "é", count: limit + 1))
        #expect(longer.fileName?.wireLength == limit)
    }

    /// The cap is the room's: a conversation's 5 MB would refuse what a group's 25 MB takes.
    @Test func aFileOverTheRoomsCapIsRefusedBeforeTheCopy() async throws {
        let caps = AttachmentCaps(imageMaxBytes: 10, videoMaxBytes: 10, fileMaxBytes: 10)
        let big = try file(named: "big.bin", bytes: 11)

        await #expect(throws: AppError.attachmentTooLarge(caps: caps)) {
            try await makePreparer().prepareFile(at: big, id: "f5", caps: caps)
        }
        #expect(AttachmentCaps.direct.fileMaxBytes < AttachmentCaps.group.fileMaxBytes)
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "f5.bin").path()))
    }

    /// The ticket needs a positive size, so an empty file is refused here rather than by a 400 no retry could change.
    @Test func anEmptyFileIsRefused() async throws {
        let empty = try file(named: "empty.txt", bytes: 0)

        await #expect(throws: AppError.attachmentTypeNotAllowed) {
            try await makePreparer().prepareFile(at: empty, id: "f8", caps: .group)
        }
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "f8.txt").path()))
    }

    @Test func aFolderAndAMissingFileAreRefused() async throws {
        await #expect(throws: AppError.attachmentTypeNotAllowed) {
            try await makePreparer().prepareFile(at: picked, id: "f6", caps: .group)
        }
        await #expect(throws: AppError.attachmentUnavailable) {
            try await makePreparer().prepareFile(at: picked.appending(path: "gone.txt"), id: "f7", caps: .group)
        }
    }
}
