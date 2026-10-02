import Foundation

/// One attachment of a stored message, as the backend answers it (plan 2.1): what the object is, the hints the sender
/// gave (name, dimensions, duration), and presigned links that die with the backend's credentials, so the app never
/// caches a link, only the bytes under `id` (`AttachmentCache`), and refreshes a link through `AttachmentLoader`.
nonisolated struct Attachment: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let kind: AttachmentKind
    let contentType: String
    let sizeBytes: Int
    let fileName: String?
    let width: Int?
    let height: Int?
    let durationSeconds: Int?
    let url: URL
    let thumbnailUrl: URL?
    let urlExpiresAt: Date

    init(id: String,
         kind: AttachmentKind,
         contentType: String,
         sizeBytes: Int,
         fileName: String? = nil,
         width: Int? = nil,
         height: Int? = nil,
         durationSeconds: Int? = nil,
         url: URL,
         thumbnailUrl: URL? = nil,
         urlExpiresAt: Date) {
        self.id = id
        self.kind = kind
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.fileName = fileName
        self.width = width
        self.height = height
        self.durationSeconds = durationSeconds
        self.url = url
        self.thumbnailUrl = thumbnailUrl
        self.urlExpiresAt = urlExpiresAt
    }

    /// Width over height when both hints are known, for a gallery to size a single picture.
    var aspectRatio: CGFloat? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        return CGFloat(width) / CGFloat(height)
    }

    /// The link of `variant`; a thumbnail falls back to the full object when none was uploaded.
    func url(for variant: AttachmentVariant) -> URL {
        switch variant {
        case .full: url
        case .thumbnail: thumbnailUrl ?? url
        }
    }

    /// The same attachment with the links a refresh answered.
    func refreshed(with link: AttachmentLink) -> Attachment {
        Attachment(id: id,
                   kind: kind,
                   contentType: contentType,
                   sizeBytes: sizeBytes,
                   fileName: fileName,
                   width: width,
                   height: height,
                   durationSeconds: durationSeconds,
                   url: link.url,
                   thumbnailUrl: link.thumbnailUrl,
                   urlExpiresAt: link.urlExpiresAt)
    }
}

/// Which object of an attachment: the full one, or the thumbnail the transcript renders.
nonisolated enum AttachmentVariant: Hashable, Sendable {
    case full
    case thumbnail

    /// What the cache appends to the attachment id for this variant's file.
    var fileSuffix: String {
        switch self {
        case .full: ""
        case .thumbnail: AppConfig.Chat.Attachments.thumbnailFileSuffix
        }
    }
}
