import SwiftUI

/// One picture in a stored message's bubble: its thumbnail through the `AttachmentLoader` (the cache first, so a
/// picture seen once never downloads again), the tile's stand-in until then. A tap opens the viewer.
struct ImageAttachmentView: View {
    let attachment: Attachment
    let message: ChatMessage
    let loader: AttachmentLoader
    let onTap: () -> Void
    @State private var picture = AttachmentImageLoad()
    @Environment(\.viewerHero) private var hero

    var body: some View {
        Button(action: onTap) {
            AttachmentTile(image: picture.image, isLoading: picture.isLoading)
        }
        .buttonStyle(.plain)
        .task(id: attachment.id) { await picture.load(attachment, variant: .thumbnail, in: message, through: loader) }
        .onChange(of: picture.image, initial: true) { _, image in hero?.noteThumbnail(image, for: attachment.id) }
        .accessibilityLabel(AppBranding.Chat.Attachments.photo)
        .accessibilityIdentifier(AccessibilityIdentifiers.messageAttachmentImage(id: attachment.id))
    }
}
