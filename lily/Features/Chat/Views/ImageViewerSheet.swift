import SwiftUI

/// The full picture over black: pinch to zoom up to `viewerMaxZoom`, double-tap to reset, Close and Share in glass
/// circles at the top. The full object comes through the `AttachmentLoader` like the thumbnail did. A container for
/// the UI tests (`attachment-viewer`), so Close keeps its own identifier.
struct ImageViewerSheet: View {
    let attachment: Attachment
    let message: ChatMessage
    let loader: AttachmentLoader
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var failed = false
    @State private var zoom: CGFloat = 1
    @State private var settledZoom: CGFloat = 1

    private typealias Copy = AppBranding.Chat.Attachments

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            picture
            VStack {
                controls
                Spacer()
            }
        }
        .task { await load() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.attachmentViewer)
    }

    @ViewBuilder private var picture: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(zoom)
                .gesture(magnify)
                .onTapGesture(count: 2) { settle(to: 1) }
                .accessibilityLabel(Copy.photo)
        } else if failed {
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

    private var controls: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: DesignTokens.Symbols.dismiss)
            }
            .lilyGlassIconButton()
            .accessibilityLabel(Copy.close)
            .accessibilityIdentifier(AccessibilityIdentifiers.attachmentViewerClose)
            Spacer()
            if let image {
                let picture = Image(uiImage: image)
                ShareLink(item: picture, preview: SharePreview(Copy.photo, image: picture)) {
                    Image(systemName: DesignTokens.Symbols.share)
                }
                .lilyGlassIconButton()
                .accessibilityLabel(Copy.share)
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }

    private func settle(to scale: CGFloat) {
        settledZoom = scale
        withAnimation(.smooth(duration: DesignTokens.Duration.fast)) { zoom = scale }
    }

    /// A download that fails leaves the glyph; the loader logged why.
    private func load() async {
        do {
            let url = try await loader.file(for: attachment, variant: .full, in: message)
            image = await ImageFile.load(url)
            failed = image == nil
        } catch {
            guard !AppError.isCancellation(error) else { return }
            failed = true
        }
    }
}
