import SwiftUI

/// One message's pictures and videos over black, paged from the tapped one in the gallery's order, so the ones behind a
/// "+N" tile are a swipe away; files stay cards that open in QuickLook. A picture page zooms (`ImageViewerPage`), a
/// video page plays only while it is on screen (`VideoPlayerPage`); Close, the "n / m" position and Share sit in glass
/// at the top. The viewer draws its own coming and going over the chat, which the cover leaves in place
/// (`presentationBackground(.clear)`, presented without the cover's slide): the black and the page fade in as the page
/// grows to size, Close plays that back, and a drag up or down (`ViewerDismissPan`, `ViewerDismissal`) carries the page,
/// fading the black, then flies it off the way it was thrown or springs it back; sideways stays the pager's. Not the
/// system's zoom, which hides the tile until frames after a close it does not animate. A zoomed picture does not close
/// on a drag (a double tap returns it to size first), nor does one being pinched. An accessibility container
/// (`attachment-viewer`), so Close keeps its own identifier; VoiceOver's escape closes it too.
struct AttachmentViewerSheet: View {
    let selection: AttachmentSelection
    let loader: AttachmentLoader
    @Environment(\.dismiss) private var dismiss
    /// Whether the viewer is up: false while it fades in and while Close fades it out.
    @State private var isShown = false
    @State private var index: Int
    @State private var pictures = LoadedPictures()
    /// Where the drag to close has the page, and whether it is flying off.
    @State private var drag = CGSize.zero
    @State private var isClosing = false
    /// The screen's height, safe areas included like the pager's: the closing page flies past it.
    @State private var height: CGFloat = 0
    /// The pictures zoomed in or being pinched, which a drag does not close.
    @State private var zoomedIDs: Set<String> = []

    private typealias Copy = AppBranding.Chat.Attachments

    init(selection: AttachmentSelection, loader: AttachmentLoader) {
        self.selection = selection
        self.loader = loader
        _index = State(initialValue: selection.start)
    }

    var body: some View {
        let progress = isClosing || !isShown ? 1 : ViewerDismissal.progress(of: drag)
        ZStack {
            Color.black
                .opacity(1 - progress)
                .ignoresSafeArea()
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: { height = $0 })
            pages
                .scaleEffect(1 - progress * (1 - DesignTokens.Layout.viewerDragMinimumScale))
                .offset(drag)
                .opacity(isShown ? 1 : 0)
            VStack {
                controls
                Spacer()
            }
            .opacity(1 - progress)
        }
        .gesture(ViewerDismissPan(isEnabled: isShown && !isClosing && !zoomedIDs.contains(current.id),
                                  onChanged: { drag = $0 },
                                  onEnded: letGo))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.attachmentViewer)
        .accessibilityAction(.escape) { close() }
        .presentationBackground(.clear)
        .onAppear {
            withAnimation(.easeOut(duration: DesignTokens.Duration.fast)) { isShown = true }
        }
    }

    /// Close: the opening played back, then the cover goes without its own slide. Once only, and never over a fly-off.
    private func close() {
        guard isShown, !isClosing else { return }
        withAnimation(.easeIn(duration: DesignTokens.Duration.fast), completionCriteria: .logicallyComplete) {
            isShown = false
        } completion: {
            leave()
        }
    }

    /// Takes the cover away without its slide: the viewer has already drawn its going.
    private func leave() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { dismiss() }
    }

    /// Letting go: the page carries on off the screen at the speed it was let go with and the viewer goes, or it springs
    /// back. A velocity-driven spring (`interpolatingSpring`) drew one stray frame as it came to rest, so neither move
    /// uses one.
    private func letGo(at translation: CGSize, velocity: CGSize, wasCancelled: Bool) {
        guard !wasCancelled, ViewerDismissal.closes(translation: translation, velocity: velocity) else {
            withAnimation(.spring(duration: DesignTokens.Duration.normal, bounce: 0)) { drag = .zero }
            return
        }
        let target = ViewerDismissal.flyOut(from: translation, velocity: velocity, height: height)
        let motion = ViewerDismissal.flyOutMotion(from: translation, to: target, velocity: velocity)
        withAnimation(.timingCurve(motion.curve, duration: motion.duration), completionCriteria: .logicallyComplete) {
            drag = target
            isClosing = true
        } completion: {
            leave()
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
            closeButton
            Spacer()
            if selection.media.count > 1 {
                position
            }
            Spacer()
            ShareControl(pictures: pictures, attachmentID: current.id)
        }
        .padding(DesignTokens.Spacing.lg)
    }

    private var closeButton: some View {
        Button {
            close()
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
