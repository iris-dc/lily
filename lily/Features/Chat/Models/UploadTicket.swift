import Foundation

/// Body of `POST /api/groups/{id}/uploads`: what the device is about to upload, so the backend can refuse a size or a
/// type before any bytes move. `thumbnail` is present when a thumbnail goes up with the object.
nonisolated struct UploadRequestPayload: Encodable, Hashable, Sendable {
    struct Thumbnail: Encodable, Hashable, Sendable {
        let contentType: String
        let sizeBytes: Int
    }

    let clientAttachmentId: String
    let kind: AttachmentKind
    let contentType: String
    let sizeBytes: Int
    let fileName: String?
    let width: Int?
    let height: Int?
    let durationSeconds: Int?
    let thumbnail: Thumbnail?

    init(clientAttachmentId: String,
         kind: AttachmentKind,
         contentType: String,
         sizeBytes: Int,
         fileName: String? = nil,
         width: Int? = nil,
         height: Int? = nil,
         durationSeconds: Int? = nil,
         thumbnail: Thumbnail? = nil) {
        self.clientAttachmentId = clientAttachmentId
        self.kind = kind
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.fileName = fileName
        self.width = width
        self.height = height
        self.durationSeconds = durationSeconds
        self.thumbnail = thumbnail
    }
}

/// One presigned PUT: the URL and exactly the headers the signature covers (`Content-Type`, `Content-Length`,
/// `x-amz-meta-uploader`), which the uploader sends as they are.
nonisolated struct UploadTarget: Hashable, Codable, Sendable {
    let url: URL
    let headers: [String: String]
}

/// Answer of `POST /api/groups/{id}/uploads`: the id the attachment will have, where to PUT the object and (when the
/// request named one) the thumbnail, and until when the links work.
nonisolated struct UploadTicket: Hashable, Codable, Sendable {
    let attachmentId: String
    let upload: UploadTarget
    let thumbnailUpload: UploadTarget?
    let expiresAt: Date

    init(attachmentId: String, upload: UploadTarget, thumbnailUpload: UploadTarget? = nil, expiresAt: Date) {
        self.attachmentId = attachmentId
        self.upload = upload
        self.thumbnailUpload = thumbnailUpload
        self.expiresAt = expiresAt
    }
}

/// One element of a send's `attachments`: the uploaded object by its ticket id, with the hints the backend stores
/// (it takes size and type from the bucket itself).
nonisolated struct AttachmentRef: Hashable, Codable, Sendable {
    let attachmentId: String
    let kind: AttachmentKind
    let contentType: String
    let sizeBytes: Int
    let fileName: String?
    let width: Int?
    let height: Int?
    let durationSeconds: Int?
    let hasThumbnail: Bool

    init(attachmentId: String,
         kind: AttachmentKind,
         contentType: String,
         sizeBytes: Int,
         fileName: String? = nil,
         width: Int? = nil,
         height: Int? = nil,
         durationSeconds: Int? = nil,
         hasThumbnail: Bool) {
        self.attachmentId = attachmentId
        self.kind = kind
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.fileName = fileName
        self.width = width
        self.height = height
        self.durationSeconds = durationSeconds
        self.hasThumbnail = hasThumbnail
    }
}

/// Answer of `GET /api/groups/{id}/messages/{mid}/attachments/{aid}`: fresh presigned links.
nonisolated struct AttachmentLink: Hashable, Codable, Sendable {
    let url: URL
    let thumbnailUrl: URL?
    let urlExpiresAt: Date

    init(url: URL, thumbnailUrl: URL? = nil, urlExpiresAt: Date) {
        self.url = url
        self.thumbnailUrl = thumbnailUrl
        self.urlExpiresAt = urlExpiresAt
    }
}
