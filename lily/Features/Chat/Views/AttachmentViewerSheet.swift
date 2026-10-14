import SwiftUI

/// The pictures and videos of one message over black, paged in the gallery's order from the tapped one, so the pictures
/// behind a "+N" tile are a swipe away: a picture page zooms (`ImageViewerPage`), a video page plays only while it is
/// the one on screen (`VideoPlayerPage`); files stay cards that open in QuickLook. Close, the "n / m" position and
/// Share (of the picture on screen, once it loaded) sit in glass at the top. A container for the UI tests
/// (`attachment-viewer`), so Close keeps its own identifier.
struct AttachmentViewerSheet: View {
    let selection: AttachmentSelection
    let loader: AttachmentLoader
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int
    @State private var pictures = LoadedPictures()

    private typealias Copy = AppBranding.Chat.Attachments

    init(selection: AttachmentSelection, loader: AttachmentLoader) {
        self.selection = selection
        self.loader = loader
        _index = State(initialValue: selection.start)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            pages
            VStack {
                controls
                Spacer()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.attachmentViewer)
    }

    private var current: Attachment { selection.media[index] }

    private var pages: some View {
        TabView(selection: $index) {
            ForEach(Array(selection.media.enumerated()), id: \.element.id) { offset, attachment in
                page(attachment, isCurrent: offset == index)
                    .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
    }

    @ViewBuilder private func page(_ attachment: Attachment, isCurrent: Bool) -> some View {
        if attachment.kind == .video {
            VideoPlayerPage(attachment: attachment, message: selection.message, loader: loader, isCurrent: isCurrent)
        } else {
            ImageViewerPage(attachment: attachment, message: selection.message, loader: loader) {
                pictures.byID[attachment.id] = $0
            }
        }
    }

    private var controls: some View {
        HStack {
            close
            Spacer()
            if selection.media.count > 1 {
                position
            }
            Spacer()
            ShareControl(pictures: pictures, attachmentID: current.id)
        }
        .padding(DesignTokens.Spacing.lg)
    }

    private var close: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: DesignTokens.Symbols.dismiss)
        }
        .lilyGlassIconButton()
        .accessibilityLabel(Copy.close)
        .accessibilityIdentifier(AccessibilityIdentifiers.attachmentViewerClose)
    }

    /// Digits only, so it needs no translation.
    private var position: some View {
        Text(verbatim: "\(index + 1) / \(selection.media.count)")
            .font(.caption)
            .foregroundStyle(.white)
            .accessibilityIdentifier(AccessibilityIdentifiers.attachmentViewerPosition)
    }
}

/// The pictures the pages loaded, by attachment id, so Share offers the one on screen. A reference the pages write
/// and `ShareControl` alone reads, so a picture loading as its page comes on screen re-renders that control and never
/// the pager: a `TabView` re-rendered while its page controller settled was seen stuck a third of the way between two
/// pictures (2026-10-13).
@Observable @MainActor
private final class LoadedPictures {
    var byID: [String: UIImage] = [:]
}

/// Shares the picture on screen; while the page has none (a video, or a picture still loading) the same control is
/// drawn hidden, so the caption between Close and Share never jumps.
private struct ShareControl: View {
    let pictures: LoadedPictures
    let attachmentID: String

    private typealias Copy = AppBranding.Chat.Attachments

    var body: some View {
        if let image = pictures.byID[attachmentID] {
            link(for: image)
        } else {
            link(for: UIImage())
                .hidden()
        }
    }

    private func link(for image: UIImage) -> some View {
        let picture = Image(uiImage: image)
        return ShareLink(item: picture, preview: SharePreview(Copy.photo, image: picture)) {
            Image(systemName: DesignTokens.Symbols.share)
        }
        .lilyGlassIconButton()
        .accessibilityLabel(Copy.share)
    }
}
