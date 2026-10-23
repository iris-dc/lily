import SwiftUI

/// One message's pictures and videos over black, paged from the tapped one in the gallery's order, so the ones behind a
/// "+N" tile are a swipe away; files stay cards that open in QuickLook. A picture page zooms (`ImageViewerPage`), a
/// video page plays only while it is on screen (`VideoPlayerPage`); Close, the "n / m" position and Share sit in glass
/// at the top. It opens with the system's zoom out of the tapped tile and closes back into the tile of the page on
/// screen. A drag closes it as in Photos (`ViewerDismissal`): the page follows the finger, fading the black and the
/// controls, up or down, and sideways too for a single picture; sideways is the pager's or a video's scrubber's
/// otherwise, which is why the zoom transition's own drag, which takes every direction, is off. A zoomed picture does
/// not close on a drag (a double tap returns it to size first), nor does one being pinched. An accessibility container
/// (`attachment-viewer`), so Close keeps its own identifier; VoiceOver's escape closes it too.
struct AttachmentViewerSheet: View {
    let selection: AttachmentSelection
    let loader: AttachmentLoader
    /// The tiles' namespace, which the zoom comes out of; `nil` opens it plainly.
    var zoom: Namespace.ID?
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int
    @State private var pictures = LoadedPictures()
    /// The drag to close as it goes; reset when it ends or is cancelled, settling the page back.
    @GestureState(resetTransaction: Transaction(animation: .smooth(duration: DesignTokens.Duration.fast)))
    private var drag = ViewerDismissal.Drag()
    /// Where the page was let go when the drag closes the viewer: it closes from there.
    @State private var releasedAt: CGSize?
    /// The pictures zoomed in or being pinched, which a drag does not close.
    @State private var zoomedIDs: Set<String> = []

    private typealias Copy = AppBranding.Chat.Attachments

    init(selection: AttachmentSelection, loader: AttachmentLoader, zoom: Namespace.ID? = nil) {
        self.selection = selection
        self.loader = loader
        self.zoom = zoom
        _index = State(initialValue: selection.start)
    }

    var body: some View {
        let shown = releasedAt ?? drag.carried
        let progress = ViewerDismissal.progress(of: shown)
        ZStack {
            Color.black
                .opacity(1 - progress)
                .ignoresSafeArea()
            pages
                .scaleEffect(1 - progress * (1 - DesignTokens.Layout.viewerDragMinimumScale))
                .offset(shown)
            VStack {
                controls
                Spacer()
            }
            .opacity(1 - progress)
        }
        .simultaneousGesture(dismissDrag, isEnabled: !zoomedIDs.contains(current.id))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.attachmentViewer)
        .accessibilityAction(.escape) { dismiss() }
        .presentationBackground(.clear)
        .interactiveDismissDisabled()
        .zoomsFromAttachment(current.id, in: zoom)
    }

    private var carriesHorizontally: Bool {
        ViewerDismissal.carriesHorizontally(pages: selection.media.count, isPicture: current.kind != .video)
    }

    /// The drag to close: carries the page while it carries, and on letting go closes from where the page is or lets the
    /// gesture state settle it back.
    private var dismissDrag: some Gesture {
        DragGesture()
            .updating($drag) { value, drag, _ in
                drag.follow(value.translation, carriesHorizontally: carriesHorizontally)
            }
            .onEnded { value in
                let whole = ViewerDismissal.Drag.reading(value.translation, carriesHorizontally: carriesHorizontally)
                guard whole.carried != .zero,
                      ViewerDismissal.closes(translation: value.translation, predictedEnd: value.predictedEndTranslation)
                else { return }
                releasedAt = whole.carried
                dismiss()
            }
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
            ImageViewerPage(attachment: attachment,
                            message: selection.message,
                            loader: loader,
                            onLoaded: { pictures.byID[attachment.id] = $0 },
                            onZoomed: { isZoomed in
                                if isZoomed { zoomedIDs.insert(attachment.id) } else { zoomedIDs.remove(attachment.id) }
                            })
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

/// The pictures the pages loaded, by attachment id, so Share offers the one on screen. A reference that the pages write
/// and only `ShareControl` reads, so a picture finishing its load re-renders that control and never the pager: a
/// `TabView` re-rendered while its page controller is still settling can stick between two pages.
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
