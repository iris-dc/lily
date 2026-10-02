import SwiftUI

/// One picture in a stored message's bubble: its thumbnail through the `AttachmentLoader` (the cache first, so a
/// picture seen once never downloads again), the tile's stand-in until then. A tap opens the viewer.
struct ImageAttachmentView: View {
    let attachment: Attachment
    let message: ChatMessage
    let loader: AttachmentLoader
    let onTap: () -> Void
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Button(action: onTap) {
            AttachmentTile(image: image, isLoading: image == nil && !failed)
        }
        .buttonStyle(.plain)
        .task(id: attachment.id) { await load() }
        .accessibilityLabel(AppBranding.Chat.Attachments.photo)
        .accessibilityIdentifier(AccessibilityIdentifiers.messageAttachmentImage(id: attachment.id))
    }

    /// A failed download leaves the stand-in; the loader logged why, and the full picture can still be tried in the viewer.
    private func load() async {
        do {
            let url = try await loader.file(for: attachment, variant: .thumbnail, in: message)
            image = await ImageFile.load(url)
            failed = image == nil
        } catch {
            guard !AppError.isCancellation(error) else { return }
            failed = true
        }
    }
}
