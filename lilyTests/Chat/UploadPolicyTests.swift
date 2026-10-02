import Foundation
import Testing
@testable import lily

/// The backend's ticket checks as the mock applies them: the cap per kind, the type lists, no thumbnail on a file.
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
            try UploadPolicy.check(request(kind: .file, contentType: "application/pdf", sizeBytes: 0))
        }
    }

    @Test func eachKindHasItsCap() throws {
        #expect(UploadPolicy.maxBytes(for: .image) == 10 * 1024 * 1024)
        #expect(UploadPolicy.maxBytes(for: .video) == 50 * 1024 * 1024)
        #expect(UploadPolicy.maxBytes(for: .file) == 25 * 1024 * 1024)
        try UploadPolicy.check(request(kind: .video, contentType: "video/mp4", sizeBytes: 50 * 1024 * 1024))
        #expect(throws: AppError.attachmentTooLarge) {
            try UploadPolicy.check(request(kind: .video, contentType: "video/mp4", sizeBytes: 50 * 1024 * 1024 + 1))
        }
        #expect(throws: AppError.attachmentTooLarge) {
            try UploadPolicy.check(request(kind: .file, contentType: "application/pdf", sizeBytes: 25 * 1024 * 1024 + 1))
        }
    }

    @Test func imagesAndVideosAreOnTheirListsFilesAreAnything() throws {
        try UploadPolicy.check(request(kind: .image, contentType: "image/png", sizeBytes: 1))
        try UploadPolicy.check(request(kind: .video, contentType: "video/quicktime", sizeBytes: 1))
        try UploadPolicy.check(request(kind: .file, contentType: "application/x-anything", sizeBytes: 1))
        #expect(throws: AppError.attachmentTypeNotAllowed) {
            try UploadPolicy.check(request(kind: .video, contentType: "video/webm", sizeBytes: 1))
        }
        #expect(throws: AppError.attachmentTypeNotAllowed) {
            try UploadPolicy.check(request(kind: .image, contentType: "image/tiff", sizeBytes: 1))
        }
    }

    @Test func aThumbnailIsCappedAndNeverOnAFile() throws {
        let small = UploadRequestPayload.Thumbnail(contentType: "image/jpeg", sizeBytes: 100)
        try UploadPolicy.check(request(kind: .video, contentType: "video/mp4", sizeBytes: 1, thumbnail: small))
        #expect(throws: AppError.attachmentUploadFailed) {
            try UploadPolicy.check(request(kind: .file, contentType: "application/pdf", sizeBytes: 1, thumbnail: small))
        }
        let big = UploadRequestPayload.Thumbnail(contentType: "image/jpeg", sizeBytes: 200 * 1024 + 1)
        #expect(throws: AppError.attachmentTooLarge) {
            try UploadPolicy.check(request(kind: .image, contentType: "image/jpeg", sizeBytes: 1, thumbnail: big))
        }
    }
}
