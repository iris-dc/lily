import Foundation

/// The byte caps of one room's attachments, by kind. A group room takes the full caps; a direct conversation takes
/// smaller ones for videos and files (`AppConfig.Chat.Attachments.direct*`), because anyone can start one from a
/// roster or a profile and a one-to-one room is where the storage buys the least. Pictures are re-encoded to a few
/// megabytes anyway, so their cap is the same everywhere. Laurel applies the same rule to the ticket and the send
/// (`attachments.direct-video-max-bytes`, `direct-file-max-bytes`), so what the device refuses the backend would too.
nonisolated struct AttachmentCaps: Hashable, Sendable {
    let imageMaxBytes: Int
    let videoMaxBytes: Int
    let fileMaxBytes: Int

    static let group = AttachmentCaps(imageMaxBytes: AppConfig.Chat.Attachments.imageMaxBytes,
                                      videoMaxBytes: AppConfig.Chat.Attachments.videoMaxBytes,
                                      fileMaxBytes: AppConfig.Chat.Attachments.fileMaxBytes)

    static let direct = AttachmentCaps(imageMaxBytes: AppConfig.Chat.Attachments.imageMaxBytes,
                                       videoMaxBytes: AppConfig.Chat.Attachments.directVideoMaxBytes,
                                       fileMaxBytes: AppConfig.Chat.Attachments.directFileMaxBytes)

    /// The caps of a room: a conversation's are the smaller ones, every other room's the full ones.
    static func caps(for group: SportGroup) -> AttachmentCaps {
        group.isDirect ? .direct : .group
    }

    func maxBytes(for kind: AttachmentKind) -> Int {
        switch kind {
        case .image: imageMaxBytes
        case .video: videoMaxBytes
        case .file: fileMaxBytes
        }
    }
}
