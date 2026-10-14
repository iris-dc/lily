import SwiftUI

/// One picture in a stored message's bubble: its thumbnail through the `AttachmentLoader` (the cache first, so a
/// picture seen once never downloads again), the tile's stand-in until then. A tap opens the viewer.
struct ImageAttachmentView: View {
    let attachment: Attachment
    let message: ChatMessage
    let loader: AttachmentLoader
    let onTap: () -> Void
    @State private var picture = AttachmentImageLoad()

    var body: some View {
        Button(action: onTap) {
            AttachmentTile(image: picture.image, isLoading: picture.isLoading)
        }
        .buttonStyle(.plain)
        .task(id: attachment.id) { await picture.load(attachment, variant: .thumbnail, in: message, through: loader) }
        .accessibilityLabel(AppBranding.Chat.Attachments.photo)
        .accessibilityIdentifier(AccessibilityIdentifiers.messageAttachmentImage(id: attachment.id))
    }
}
