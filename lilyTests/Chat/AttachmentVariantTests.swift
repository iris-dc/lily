import Testing
@testable import lily

/// The sizing rule of a stored picture's variants: the longest side each is decoded at, and the pixel cap over them.
@MainActor
struct AttachmentVariantTests {
    private typealias Caps = AppConfig.Chat.Attachments

    /// A tile decodes at the thumbnail's side and the viewer at the picture's: what this app's own preparer uploads.
    @Test func aThumbnailIsDecodedAtTheThumbnailsSideAndTheFullObjectAtThePicturesSide() {
        #expect(AttachmentVariant.thumbnail.maxDecodedDimension == Caps.thumbnailMaxDimension)
        #expect(AttachmentVariant.full.maxDecodedDimension == Caps.imageMaxDimension)
        #expect(Caps.thumbnailMaxDimension == 512 && Caps.imageMaxDimension == 2048)
    }

    /// Nobody lowers the cap under what the preparer sends.
    @Test func thePixelCapAdmitsEveryPictureThisAppUploads() {
        #expect(Caps.imageMaxDimension * Caps.imageMaxDimension <= Caps.imageMaxDeclaredPixels)
        #expect(Caps.thumbnailMaxDimension <= Caps.imageMaxDimension)
    }
}
