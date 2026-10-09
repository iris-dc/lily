import Foundation
import UniformTypeIdentifiers

/// Any file for upload: copied into the temporary directory under the draft's id (the importer's URL is security-scoped
/// and may be gone once its sheet is), typed from what the system knows about it (`application/octet-stream` when it
/// knows nothing) and named after itself (`AttachmentDraft` cuts the name to the backend's limit). Over the room's
/// `caps.fileMaxBytes` is refused before the copy; a folder or a package is refused as no file. One of the three
/// workers behind `DeviceMediaPreparer`. An empty file is refused too: the ticket needs a positive size.
final class FilePreparer {
    private let directory: URL
    private let logger: any Logging

    init(directory: URL = FileManager.default.temporaryDirectory, logger: any Logging) {
        self.directory = directory
        self.logger = logger
    }

    func prepareFile(at url: URL, id: String, caps: AttachmentCaps) async throws -> AttachmentDraft {
        let directory = self.directory
        let draft = try await Task.detached(priority: .userInitiated) {
            try FileCopying.prepare(at: url, id: id, caps: caps, in: directory)
        }.value
        logger.debug(.chat, "Attachment \(id) prepared: \(draft.sizeBytes) B file of type \(draft.contentType)")
        return draft
    }
}

/// The copy work of `FilePreparer`, free of any actor so it runs on a detached task.
nonisolated enum FileCopying {
    static func prepare(at url: URL, id: String, caps: AttachmentCaps, in directory: URL) throws -> AttachmentDraft {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let values = try readable(url)
        guard values.isRegularFile == true else { throw AppError.attachmentTypeNotAllowed }
        let sizeBytes = values.fileSize ?? 0
        // The ticket needs a positive size; an empty file would earn a 400 that no retry could change.
        guard sizeBytes > 0 else { throw AppError.attachmentTypeNotAllowed }
        guard sizeBytes <= caps.fileMaxBytes else { throw AppError.attachmentTooLarge(caps: caps) }
        let fileURL = directory.appending(path: url.pathExtension.isEmpty ? id : "\(id).\(url.pathExtension)")
        try copy(url, to: fileURL)
        return AttachmentDraft(clientAttachmentID: id,
                               kind: .file,
                               fileURL: fileURL,
                               contentType: contentType(values.contentType, extension: url.pathExtension),
                               sizeBytes: sizeBytes,
                               fileName: url.lastPathComponent)
    }

    /// The system's type when it has one (from the file's own metadata, else its extension), or the octet stream.
    static func contentType(_ type: UTType?, extension: String) -> String {
        (type ?? UTType(filenameExtension: `extension`))?.preferredMIMEType ?? AppConfig.Chat.Attachments.fallbackFileContentType
    }

    /// A file the device cannot read (gone, or a provider that will not serve it) is unavailable, not a type verdict.
    private static func readable(_ url: URL) throws -> URLResourceValues {
        do {
            return try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentTypeKey])
        } catch {
            throw AppError.attachmentUnavailable
        }
    }

    private static func copy(_ url: URL, to fileURL: URL) throws {
        try? FileManager.default.removeItem(at: fileURL)
        do {
            try FileManager.default.copyItem(at: url, to: fileURL)
        } catch {
            throw AppError.attachmentUnavailable
        }
    }
}
