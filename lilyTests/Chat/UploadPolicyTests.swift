import Foundation
import Testing
@testable import lily

/// The backend's ticket checks as the mock applies them: the cap per kind, the type lists, no thumbnail on a file, and no
/// ticket at all for a kind this build does not know.
struct UploadPolicyTests {
    private func request(kind: AttachmentKind,
                         contentType: String,
                         sizeBytes: Int,
                         thumbnail: UploadRequestPayload.Thumbnail? = nil) -> UploadRequestPayload {
        UploadRequestPayload(clientAttachmentId: "c",
                             kind: kind,
                             contentType: contentType,
                             sizeBytes: sizeBytes,
                             thumbnail: thumbnail)
    }

    /// Laurel's `@Positive sizeBytes` is a `400 VALIDATION_FAILED`, which reaches the app as the ticket's fallback.
    @Test func anEmptyObjectIsRefusedLikeTheBackendsValidation() {
        #expect(throws: AppError.attachmentUploadFailed) {
            try UploadPolicy.check(request(kind: .file, contentType: "application/pdf", sizeBytes: 0), caps: .group)
        }
    }

    /// The boundary of the cap per kind, read from `AttachmentCaps`, whose own tests pin the numbers.
    @Test func aRequestAtTheCapPassesAndOneByteOverIsRefused() throws {
        let videoCap = AttachmentCaps.group.maxBytes(for: .video)
        let fileCap = AttachmentCaps.group.maxBytes(for: .file)
        try UploadPolicy.check(request(kind: .video, contentType: "video/mp4", sizeBytes: videoCap), caps: .group)
        #expect(throws: AppError.attachmentTooLarge(caps: .group)) {
            try UploadPolicy.check(request(kind: .video, contentType: "video/mp4", sizeBytes: videoCap + 1), caps: .group)
        }
        #expect(throws: AppError.attachmentTooLarge(caps: .group)) {
            try UploadPolicy.check(request(kind: .file, contentType: "application/pdf", sizeBytes: fileCap + 1),
                                   caps: .group)
        }
    }

    @Test func imagesAndVideosAreOnTheirListsFilesAreAnything() throws {
        try UploadPolicy.check(request(kind: .image, contentType: "image/png", sizeBytes: 1), caps: .group)
        try UploadPolicy.check(request(kind: .video, contentType: "video/quicktime", sizeBytes: 1), caps: .group)
        try UploadPolicy.check(request(kind: .file, contentType: "application/x-anything", sizeBytes: 1), caps: .group)
        #expect(throws: AppError.attachmentTypeNotAllowed) {
            try UploadPolicy.check(request(kind: .video, contentType: "video/webm", sizeBytes: 1), caps: .group)
        }
        #expect(throws: AppError.attachmentTypeNotAllowed) {
            try UploadPolicy.check(request(kind: .image, contentType: "image/tiff", sizeBytes: 1), caps: .group)
        }
    }

    @Test func aThumbnailIsCappedAndNeverOnAFile() throws {
        let small = Self.smallThumbnail
        try UploadPolicy.check(request(kind: .video, contentType: "video/mp4", sizeBytes: 1, thumbnail: small), caps: .group)
        #expect(throws: AppError.attachmentUploadFailed) {
            try UploadPolicy.check(request(kind: .file, contentType: "application/pdf", sizeBytes: 1, thumbnail: small),
                                   caps: .group)
        }
        let big = UploadRequestPayload.Thumbnail(contentType: "image/jpeg", sizeBytes: 200 * 1024 + 1)
        #expect(throws: AppError.attachmentTooLarge(caps: .group)) {
            try UploadPolicy.check(request(kind: .image, contentType: "image/jpeg", sizeBytes: 1, thumbnail: big), caps: .group)
        }
    }

    /// The device never asks for a ticket of a kind it does not know; were one asked, no content type is allowed for it.
    @Test func anUnknownKindIsRefusedAsATypeNotAllowed() {
        #expect(!UploadPolicy.allows("audio/m4a", for: .unknown("audio")))
        #expect(!UploadPolicy.allows("application/octet-stream", for: .unknown("audio")), "not even a file's anything")
        #expect(throws: AppError.attachmentTypeNotAllowed) {
            try UploadPolicy.check(request(kind: .unknown("audio"), contentType: "audio/m4a", sizeBytes: 100), caps: .group)
        }
    }

    /// The thumbnail check runs before the type check, as in the backend, so a thumbnail on a kind this build does not
    /// know is refused the way one on a file is.
    @Test func aThumbnailOnAnUnknownKindIsRefusedLikeOnAFile() {
        #expect(throws: AppError.attachmentUploadFailed) {
            try UploadPolicy.check(request(kind: .unknown("audio"),
                                           contentType: "audio/m4a",
                                           sizeBytes: 100,
                                           thumbnail: Self.smallThumbnail),
                                   caps: .group)
        }
    }

    private static let smallThumbnail = UploadRequestPayload.Thumbnail(contentType: "image/jpeg", sizeBytes: 100)
}
