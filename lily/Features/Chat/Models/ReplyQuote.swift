import Foundation

/// The compact quote a reply carries: the backend snapshots it onto the message when the reply is stored, so a page
/// needs no lookup, and the app builds the same shape locally for the composer's preview and the unsent bubble.
/// `excerpt` is the target's text cut to `AppConfig.Chat.replyExcerptLength`, absent when the target had none;
/// `attachmentKind` names the first attachment of a media target. The server never rewrites a stored quote, so whether
/// the original is gone is this device's knowledge (`ChatViewModel.quoteIsDeleted`).
nonisolated struct ReplyQuote: Hashable, Codable, Sendable {
    let messageId: String
    let senderUserId: String
    let senderName: String
    let excerpt: String?
    let kind: MessageKind
    let attachmentKind: AttachmentKind?

    init(messageId: String,
         senderUserId: String,
         senderName: String,
         excerpt: String? = nil,
         kind: MessageKind = .text,
         attachmentKind: AttachmentKind? = nil) {
        self.messageId = messageId
        self.senderUserId = senderUserId
        self.senderName = senderName
        self.excerpt = excerpt
        self.kind = kind
        self.attachmentKind = attachmentKind
    }

    /// The quote of `message` as the backend would store it, named after `senderName` (the sender's current name
    /// when the roster knows it) and after the first attachment's kind when the message carries any; a poll's excerpt
    /// is its question. The one place a
    /// message becomes a quote; the mock repository snapshots through it too.
    init(quoting message: ChatMessage, senderName: String) {
        self.init(messageId: message.id,
                  senderUserId: message.senderUserId,
                  senderName: senderName,
                  excerpt: (message.text ?? message.poll?.question)?.prefix(wireLength: AppConfig.Chat.replyExcerptLength),
                  kind: message.kind,
                  attachmentKind: message.attachments.first?.kind)
    }

    /// Stands in for the excerpt of a media target without text: "Photo", "Video" or "File"; a kind this build does not
    /// know is drawn as a file, so it reads as one here too.
    var placeholder: String? {
        switch attachmentKind {
        case .image: AppBranding.Chat.quotedPhoto
        case .video: AppBranding.Chat.quotedVideo
        case .file, .unknown: AppBranding.Chat.quotedFile
        case nil: nil
        }
    }

    /// What the quote shows under the sender's name: the excerpt (a poll's question, marked as a poll), else the
    /// placeholder.
    var displayText: String {
        if kind == .poll { return AppBranding.Chat.Polls.quoted(excerpt ?? "") }
        return excerpt ?? placeholder ?? ""
    }
}
