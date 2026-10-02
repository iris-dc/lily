import Foundation

/// The backend's checks on an upload ticket (Laurel's `AttachmentPolicy`), kept here so the mock refuses what the
/// bucket would: a positive size, the kind's byte cap, the thumbnail's cap, the image and video type lists, and no
/// thumbnail on a file (a `400 VALIDATION_FAILED` there, which reaches the app as the ticket's fallback error).
nonisolated enum UploadPolicy {
    static func check(_ request: UploadRequestPayload) throws {
        guard request.sizeBytes > 0 else { throw AppError.attachmentUploadFailed }
        guard request.sizeBytes <= maxBytes(for: request.kind) else { throw AppError.attachmentTooLarge }
        if let thumbnail = request.thumbnail {
            guard request.kind != .file else { throw AppError.attachmentUploadFailed }
            guard thumbnail.sizeBytes <= AppConfig.Chat.Attachments.thumbnailMaxBytes else { throw AppError.attachmentTooLarge }
        }
        guard allows(request.contentType, for: request.kind) else { throw AppError.attachmentTypeNotAllowed }
    }

    static func maxBytes(for kind: AttachmentKind) -> Int {
        switch kind {
        case .image: AppConfig.Chat.Attachments.imageMaxBytes
        case .video: AppConfig.Chat.Attachments.videoMaxBytes
        case .file: AppConfig.Chat.Attachments.fileMaxBytes
        }
    }

    /// Images and videos are on their lists; a file may be anything.
    static func allows(_ contentType: String, for kind: AttachmentKind) -> Bool {
        switch kind {
        case .image: AppConfig.Chat.Attachments.imageContentTypes.contains(contentType)
        case .video: AppConfig.Chat.Attachments.videoContentTypes.contains(contentType)
        case .file: true
        }
    }
}
