import Foundation
@testable import lily

extension Attachment {
    /// A stored video with its thumbnail and a stored file without one, both with links good for an hour.
    static func videoFixture(id: String = "vid-1") -> Attachment {
        Attachment(id: id,
                   kind: .video,
                   contentType: "video/mp4",
                   sizeBytes: 5_242_880,
                   width: 1280,
                   height: 720,
                   durationSeconds: 12,
                   url: URL(string: "https://files.test/chat/g/\(id)")!,
                   thumbnailUrl: URL(string: "https://files.test/chat/g/\(id)/thumb")!,
                   urlExpiresAt: Date(timeIntervalSince1970: 1_800_003_600))
    }

    static func fileFixture(id: String = "file-1", fileName: String? = "training-plan.pdf") -> Attachment {
        Attachment(id: id,
                   kind: .file,
                   contentType: "application/pdf",
                   sizeBytes: 19_358,
                   fileName: fileName,
                   url: URL(string: "https://files.test/chat/g/\(id)")!,
                   urlExpiresAt: Date(timeIntervalSince1970: 1_800_003_600))
    }
}

extension UploadTicket {
    static func fixture(attachmentID: String = "att-1", thumbnail: Bool = true) -> UploadTicket {
        let headers = ["Content-Type": "image/jpeg", "x-amz-meta-uploader": TestFixtures.user.id]
        let base = "https://files.test/chat/g/\(attachmentID)"
        return UploadTicket(attachmentId: attachmentID,
                            upload: UploadTarget(url: URL(string: base)!, headers: headers),
                            thumbnailUpload: thumbnail ? UploadTarget(url: URL(string: "\(base)/thumb")!, headers: headers) : nil,
                            expiresAt: Date(timeIntervalSince1970: 1_800_000_900))
    }
}

extension Attachment {
    /// A stored image with links good for an hour from the fixtures' clock.
    static func fixture(id: String = "att-1",
                        url: URL = URL(string: "https://files.test/chat/g/att-1")!,
                        thumbnailUrl: URL? = URL(string: "https://files.test/chat/g/att-1/thumb")!,
                        expiresAt: Date = Date(timeIntervalSince1970: 1_800_003_600)) -> Attachment {
        Attachment(id: id,
                   kind: .image,
                   contentType: "image/jpeg",
                   sizeBytes: 812_345,
                   width: 2048,
                   height: 1536,
                   url: url,
                   thumbnailUrl: thumbnailUrl,
                   urlExpiresAt: expiresAt)
    }

    /// The stored form of a ref the fake repository echoes back.
    static func fixture(from ref: AttachmentRef) -> Attachment {
        Attachment(id: ref.attachmentId,
                   kind: ref.kind,
                   contentType: ref.contentType,
                   sizeBytes: ref.sizeBytes,
                   fileName: ref.fileName,
                   width: ref.width,
                   height: ref.height,
                   durationSeconds: ref.durationSeconds,
                   url: URL(string: "https://files.test/chat/g/\(ref.attachmentId)")!,
                   thumbnailUrl: ref.hasThumbnail ? URL(string: "https://files.test/chat/g/\(ref.attachmentId)/thumb") : nil,
                   urlExpiresAt: Date(timeIntervalSince1970: 1_800_003_600))
    }
}
