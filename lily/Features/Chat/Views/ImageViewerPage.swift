import SwiftUI

/// One page of `AttachmentViewerSheet`: the full picture through the `AttachmentLoader`, pinch to zoom up to
/// `viewerMaxZoom`, double-tap to reset; `onLoaded` hands the picture up so the pager can offer it to Share. No
/// identifier of its own: the pager is the container the UI tests find.
struct ImageViewerPage: View {
    let attachment: Attachment
    let message: ChatMessage
    let loader: AttachmentLoader
    var onLoaded: (UIImage) -> Void = { _ in }
    @State private var picture = AttachmentImageLoad()
    @State private var zoom: CGFloat = 1
    @State private var settledZoom: CGFloat = 1

    private typealias Copy = AppBranding.Chat.Attachments

    var body: some View {
        content
            .task {
                if let loaded = await picture.load(attachment, variant: .full, in: message, through: loader) {
                    onLoaded(loaded)
                }
            }
    }

    @ViewBuilder private var content: some View {
        if let image = picture.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(zoom)
                .gesture(magnify)
                .onTapGesture(count: 2) { settle(to: 1) }
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
            .onChanged { zoom = settledZoom * $0.magnification }
            .onEnded { _ in settle(to: min(max(zoom, 1), DesignTokens.Layout.viewerMaxZoom)) }
    }

    private func settle(to scale: CGFloat) {
        settledZoom = scale
        withAnimation(.smooth(duration: DesignTokens.Duration.fast)) { zoom = scale }
    }
}
