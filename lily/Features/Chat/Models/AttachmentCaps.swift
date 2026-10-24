import Foundation

/// The byte caps of one room's attachments, by kind. A group room takes the full caps; a direct conversation takes a
/// smaller one for videos (`AppConfig.Chat.Attachments.direct*`), because anyone can start one from a roster or a
/// profile and a one-to-one room is where the storage buys the least. Files and pictures take the group's caps
/// there: files by their own key, which Laurel keeps too, and pictures because they are re-encoded to a few
/// megabytes anyway. Laurel applies the same rule to the ticket and the send
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

    /// The cap for a kind; a kind this build does not know is capped like a file.
    func maxBytes(for kind: AttachmentKind) -> Int {
        switch kind {
        case .image: imageMaxBytes
        case .video: videoMaxBytes
        case .file, .unknown: fileMaxBytes
        }
    }

    /// The one over-cap verdict: `sizeBytes` within the kind's cap, else `.attachmentTooLarge` carrying these caps, so
    /// the popup names the numbers of the room the item was meant for.
    func require(sizeBytes: Int, for kind: AttachmentKind) throws {
        guard sizeBytes <= maxBytes(for: kind) else { throw AppError.attachmentTooLarge(caps: self) }
    }
}
