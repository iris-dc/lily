import Foundation
import UniformTypeIdentifiers

/// The full object of an attachment as a named file, for QuickLook and the player: the cache keeps bytes under the
/// attachment id alone, and both QuickLook and `AVPlayer` decide what they are looking at from the name and extension.
/// The copy is made off the main actor (the fallback to a hard link writes up to 25 MB), and a copy the file system
/// refuses is logged here, where the id and the error meet; the cards and the player stay silent.
extension AttachmentLoader {
    /// A file named after the attachment (its sender's name for it, else the id with the content type's extension)
    /// holding the full object, downloaded first when the cache has no copy, with `progress` along the way. A copy the
    /// file system refuses is `.attachmentUnavailable`; the download itself stays cached.
    func previewFile(for attachment: Attachment, in message: ChatMessage, progress: ProgressHandler? = nil) async throws -> URL {
        let cached = try await file(for: attachment, variant: .full, in: message, progress: progress)
        let name = PreviewFiles.name(for: attachment)
        let id = attachment.id
        let directory = previewDirectory
        do {
            return try await Task.detached(priority: .userInitiated) {
                try PreviewFiles.named(name, for: id, linking: cached, in: directory)
            }.value
        } catch {
            logger.error(.chat, "Preview copy failed for attachment \(id): \(error)")
            throw AppError.attachmentUnavailable
        }
    }
}

/// `tmp/AttachmentPreviews/<id>/<name>`: one folder per attachment, so two files with the same name never collide, and
/// a hard link to the cached bytes (a copy when the link fails), so a 25 MB document is not written twice.
nonisolated enum PreviewFiles {
    static var directory: URL {
        FileManager.default.temporaryDirectory.appending(path: AppConfig.Chat.Attachments.previewDirectoryName)
    }

    /// The sender's name for the file when it carries an extension; else the name (or the id) with the extension the
    /// content type is known by, so a video sent from the camera roll opens as `<id>.mp4`. The name becomes a path
    /// component here, so only its last component is used and `.`/`..` fall back to the id (the backend strips
    /// separators already; the mock passes the sender's own name through).
    static func name(for attachment: Attachment) -> String {
        let name = safeName(attachment.fileName) ?? attachment.id
        guard URL(fileURLWithPath: name).pathExtension.isEmpty,
              let extensionName = UTType(mimeType: attachment.contentType)?.preferredFilenameExtension else {
            return name
        }
        return "\(name).\(extensionName)"
    }

    private static func safeName(_ fileName: String?) -> String? {
        guard let component = fileName?.split(separator: "/").last.map(String.init),
              component != ".", component != ".." else { return nil }
        return component
    }

    /// `<directory>/<id>/<name>` linked to `source`, replacing a copy already there.
    static func named(_ name: String,
                      for id: String,
                      linking source: URL,
                      in directory: URL = PreviewFiles.directory) throws -> URL {
        let folder = directory.appending(path: id)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: name)
        try? FileManager.default.removeItem(at: url)
        do {
            try FileManager.default.linkItem(at: source, to: url)
        } catch {
            try FileManager.default.copyItem(at: source, to: url)
        }
        return url
    }

    /// The preview's folder, once QuickLook is done with it.
    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    /// Every preview copy; the disk cache's sign-out sweep calls it, because a hard link keeps a cleared object's bytes
    /// alive until the link goes too.
    static func removeAll(in directory: URL = PreviewFiles.directory) throws {
        try FileManager.default.removeItemIfPresent(at: directory)
    }
}
