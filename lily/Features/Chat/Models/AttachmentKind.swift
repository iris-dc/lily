import Foundation

/// What an attachment is on the wire; a reply quote names the first attachment of a media target by it.
nonisolated enum AttachmentKind: String, Codable, Sendable {
    case image
    case video
    case file

    /// Pictures and videos are tiles of a bubble's gallery grid; files are cards under it.
    var isMedia: Bool { self != .file }
}
