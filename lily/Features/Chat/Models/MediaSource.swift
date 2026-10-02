import Foundation

/// What a picker handed the composer, before the preparer has worked on it: the bytes of a picture, or the file of a
/// video or of any document (a copy the picker made, or a security-scoped URL the preparer reads under its scope).
/// Plain data, so the composer's preparation task carries it without capturing a closure.
nonisolated enum MediaSource: Hashable, Sendable {
    case image(Data)
    case video(URL)
    case file(URL)

    var kind: AttachmentKind {
        switch self {
        case .image: .image
        case .video: .video
        case .file: .file
        }
    }

    /// The name a file slot shows before the preparer answers; pictures and videos have none.
    var fileName: String? {
        if case .file(let url) = self { return url.lastPathComponent }
        return nil
    }
}
