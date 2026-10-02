import Foundation

/// Identifiers of the chat's attachments; mirrored by hand in `lilyUITests` like the rest.
nonisolated extension AccessibilityIdentifiers {
    /// The composer's attach menu (a "+" leading the field).
    static let chatAttach = "chat-attach"
    /// The strip of picked pictures above the field (a container; its tiles keep their own identifiers).
    static let chatAttachmentStrip = "chat-attachment-strip"
    /// The full-screen viewer and the video player (containers) and their Close button.
    static let attachmentViewer = "attachment-viewer"
    static let attachmentViewerClose = "attachment-viewer-close"

    /// A picked picture in the strip, keyed by the id chosen for it on the device.
    static func chatAttachment(clientID: String) -> String {
        "chat-attachment-\(clientID)"
    }

    /// The X that drops a picked picture.
    static func chatAttachmentRemove(clientID: String) -> String {
        "chat-attachment-remove-\(clientID)"
    }

    /// A picture in a stored message's bubble, keyed by the attachment's server id.
    static func messageAttachmentImage(id: String) -> String {
        "message-attachment-image-\(id)"
    }

    /// A video tile in a stored message's bubble.
    static func messageAttachmentVideo(id: String) -> String {
        "message-attachment-video-\(id)"
    }

    /// A file card in a stored message's bubble.
    static func messageAttachmentFile(id: String) -> String {
        "message-attachment-file-\(id)"
    }
}
