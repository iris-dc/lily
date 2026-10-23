import SwiftUI

/// One page of `AttachmentViewerSheet`: the full picture through the `AttachmentLoader`, the thumbnail until it lands
/// (the tile's, or loaded here for a picture behind "+N" and handed up through `onPreview`), fitted to the page; pinch
/// to zoom up to `viewerMaxZoom`, double-tap to reset. `onLoaded` hands the full picture up so the pager can offer it to
/// Share, and `onZoomed` tells it whether the picture is zoomed in or being pinched, when a drag does not close the
/// viewer. No identifier of its own: the pager is the container the UI tests find.
struct ImageViewerPage: View {
    let attachment: Attachment
    let message: ChatMessage
    let loader: AttachmentLoader
    /// The tile's thumbnail, when the chat had it on screen.
    var thumbnail: UIImage?
    var onPreview: (UIImage) -> Void = { _ in }
    var onLoaded: (UIImage) -> Void = { _ in }
    var onZoomed: (Bool) -> Void = { _ in }
    @State private var picture = AttachmentImageLoad()
    @State private var preview = AttachmentImageLoad()
    @State private var zoom: CGFloat = 1
    @State private var settledZoom: CGFloat = 1
    /// Whether a pinch is under way; back to false however it ends, a cancel included.
    @GestureState private var isPinching = false

    private typealias Copy = AppBranding.Chat.Attachments

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                if let loaded = await picture.load(attachment, variant: .full, in: message, through: loader) {
                    onLoaded(loaded)
                }
            }
            .task {
                guard thumbnail == nil else { return }
                if let loaded = await preview.load(attachment, variant: .thumbnail, in: message, through: loader) {
                    onPreview(loaded)
                }
            }
            // From the first appearance, so a page the pager made again at full size clears what its last one reported.
            .onChange(of: isPinching || settledZoom > 1, initial: true) { _, isZoomed in onZoomed(isZoomed) }
            .onChange(of: isPinching) { _, pinching in
                if !pinching { settle(to: min(max(zoom, 1), DesignTokens.Layout.viewerMaxZoom)) }
            }
    }

    @ViewBuilder private var content: some View {
        if let image = picture.image ?? preview.image ?? thumbnail {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(zoom)
                .gesture(magnify)
                .onTapGesture(count: 2) { settle(to: 1) }
                .overlay {
                    if picture.isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .accessibilityLabel(Copy.photo)
        } else if picture.failed {
            Image(systemName: DesignTokens.Symbols.photoLibrary)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
        } else {
            ProgressView()
                .tint(.white)
        }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .updating($isPinching) { _, pinching, _ in pinching = true }
            .onChanged { zoom = settledZoom * $0.magnification }
    }

    private func settle(to scale: CGFloat) {
        settledZoom = scale
        withAnimation(.smooth(duration: DesignTokens.Duration.fast)) { zoom = scale }
    }
}
