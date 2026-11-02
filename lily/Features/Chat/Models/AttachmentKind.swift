import Foundation

/// What an attachment is on the wire: a picture, a video or a file. A kind a newer backend sends keeps its name, is no
/// media and draws as a file card, so a page, a sent message or an envelope carrying it still decodes. A reply quote
/// names the first attachment of a media target by it.
nonisolated enum AttachmentKind: WireNamedKind {
    case image
    case video
    case file
    case unknown(String)

    static let known: [AttachmentKind] = [.image, .video, .file]

    private static let imageName = "image"
    private static let videoName = "video"
    private static let fileName = "file"

    var wireName: String {
        switch self {
        case .image: Self.imageName
        case .video: Self.videoName
        case .file: Self.fileName
        case .unknown(let name): name
        }
    }

    /// Pictures and videos are tiles of a bubble's gallery grid; files, and any kind this build does not know, are
    /// cards under it.
    var isMedia: Bool {
        switch self {
        case .image, .video: true
        case .file, .unknown: false
        }
    }
}
