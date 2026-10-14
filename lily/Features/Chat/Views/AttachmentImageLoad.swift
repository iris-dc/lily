import SwiftUI

/// The state of one picture a view brings through the `AttachmentLoader`: nothing yet, the decoded picture, or
/// failed (a refused or lost download, bytes that are no picture, or no object to fetch at all). The loader logged why
/// a download failed, so nothing is logged here. A refusal met after the caller left (its task cancelled) leaves the
/// state as it was, so a page swiped away mid-download never shows the failed glyph when it comes back; a download
/// that still lands is kept, since the loader shares it with anyone else asking. Nothing resets when a view's
/// `.task(id:)` re-runs for another attachment, as the `@State` pair it replaced did not either.
@Observable @MainActor
final class AttachmentImageLoad {
    private(set) var image: UIImage?
    private(set) var failed = false

    var isLoading: Bool { image == nil && !failed }

    /// Brings the `variant` of `attachment` and decodes it; answers the picture so a caller can hand it on. `available`
    /// is `false` for a video without a thumbnail: the tile shows its stand-in rather than downloading the whole clip
    /// for a frame.
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
            let loaded = await ImageFile.load(url)
            image = loaded
            failed = loaded == nil
            return loaded
        } catch {
            guard !AppError.isCancellation(error) else { return nil }
            failed = true
            return nil
        }
    }
}
