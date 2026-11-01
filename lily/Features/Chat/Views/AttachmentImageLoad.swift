import SwiftUI

/// The state of one picture a view brings through the `AttachmentLoader`: nothing yet, the decoded picture, or failed
/// (a refused or lost download, bytes that are no picture, a picture declaring more pixels than the cap, or nothing to
/// fetch); the loader logs why a download failed, this box why a picture was not decoded. The picture is decoded at
/// the side of the variant asked for (`AttachmentVariant.maxDecodedDimension`, where that rule lives).
/// A cancellation leaves the state as it was, so a page swiped away mid-download never shows the failed glyph when it
/// comes back, and a download that still lands is kept, since the loader shares it with anyone else asking. Nothing
/// resets when a view's `.task(id:)` re-runs for another attachment.
@Observable @MainActor
final class AttachmentImageLoad {
    private(set) var image: UIImage?
    private(set) var failed = false

    var isLoading: Bool { image == nil && !failed }

    /// Fetches and decodes `variant` of `attachment`, answering the picture so a caller can hand it on. `available` is
    /// `false` for a video without a thumbnail: the tile shows its stand-in rather than downloading the whole clip for a
    /// frame.
    @discardableResult
    func load(_ attachment: Attachment,
              variant: AttachmentVariant,
              in message: ChatMessage,
              through loader: AttachmentLoader,
              available: Bool = true) async -> UIImage? {
        guard available else {
            failed = true
            return nil
        }
        do {
            let url = try await loader.file(for: attachment, variant: variant, in: message)
            let loaded = try await ImageFile.load(url, maxDimension: variant.maxDecodedDimension)
            image = loaded
            failed = false
            return loaded
        } catch {
            guard !AppError.isCancellation(error) else { return nil }
            logRefusal(error, of: attachment, through: loader)
            failed = true
            return nil
        }
    }

    /// A picture refused at its header is a refusal the screen expects: one warning naming the id and the declared size.
    private func logRefusal(_ error: any Error, of attachment: Attachment, through loader: AttachmentLoader) {
        guard case ImageFile.Refusal.overThePixelCap(let width, let height) = error else { return }
        loader.logger.warning(.chat, "Attachment \(attachment.id) not decoded: \(width)x\(height) declared, over the pixel cap")
    }
}
