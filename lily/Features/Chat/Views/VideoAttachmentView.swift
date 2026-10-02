import SwiftUI

/// One video in a stored message's bubble: its thumbnail through the `AttachmentLoader` like a picture's, a play badge
/// over it and the length in the corner; a tap hands the attachment up and the transcript opens the player. A video
/// that came without a thumbnail shows the badge over the tile's stand-in rather than downloading the whole clip for a
/// frame.
struct VideoAttachmentView: View {
    let attachment: Attachment
    let message: ChatMessage
    let loader: AttachmentLoader
    let onTap: () -> Void
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Button(action: onTap) {
            AttachmentTile(image: image,
                           isLoading: image == nil && !failed,
                           placeholderSymbol: DesignTokens.Symbols.videoPlaceholder)
                .overlay { PlayBadge(size: DesignTokens.Layout.playBadgeSize) }
                .overlay(alignment: .bottomTrailing) {
                    if let seconds = attachment.durationSeconds { DurationBadge(seconds: seconds) }
                }
        }
        .buttonStyle(.plain)
        .task(id: attachment.id) { await load() }
        .accessibilityLabel(AppBranding.Chat.Attachments.video)
        .accessibilityIdentifier(AccessibilityIdentifiers.messageAttachmentVideo(id: attachment.id))
    }

    /// A failed download leaves the stand-in; the loader logged why, and the clip can still be played.
    private func load() async {
        guard attachment.thumbnailUrl != nil else {
            failed = true
            return
        }
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

/// The play glyph in a dark circle over a video, in a bubble and on a strip tile.
struct PlayBadge: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: DesignTokens.Symbols.play)
            .font(.system(size: size * DesignTokens.Layout.playGlyphFraction, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.black.opacity(DesignTokens.Opacity.playBadgeBacking), in: .circle)
            .accessibilityHidden(true)
    }
}

/// "0:12" in a dark capsule at a video tile's corner.
struct DurationBadge: View {
    let seconds: Int

    var body: some View {
        Text(VideoCaption.duration(seconds))
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs / 2)
            .background(Color.black.opacity(DesignTokens.Opacity.playBadgeBacking), in: .capsule)
            .padding(DesignTokens.Spacing.sm)
            .accessibilityHidden(true)
    }
}
