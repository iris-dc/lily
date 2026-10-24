import SwiftUI

/// One message's pictures and videos over black, paged from the tapped one in the gallery's order, so the ones behind a
/// "+N" tile are a swipe away; files stay cards that open in QuickLook. A picture page zooms (`ImageViewerPage`), a
/// video page plays only while it is on screen (`VideoPlayerPage`); Close, the "n / m" position and Share sit in glass
/// at the top. The viewer draws its own coming and going over the chat, which the cover leaves in place
/// (`presentationBackground(.clear)`, presented and taken away without the cover's slide): the picture grows out of its
/// tile to fill the screen as the black comes in, and the tile shows the accent while its picture is in the viewer
/// (`ViewerHero`). A drag up or down (`ViewerDismissPan`, `ViewerDismissal`) moves the picture up or down only, at full
/// size, fading the black so the chat shows through; letting go far enough, or Close, or VoiceOver's escape, puts it
/// back onto its tile, the one of the page on screen, and the chat is back; short of it the picture springs back.
/// On the way in and out, and while dragged, the picture is drawn by itself over the hidden pager, each move's ends as
/// `ViewerGeometry` places them from where its page lays the picture out (SwiftUI draws the frames between, which the
/// geometry's linearity keeps on the path): a transformed pager re-laid its UIKit page out on alternate frames. A video
/// moves as its poster. Without a picture or a tile (a page with nothing loaded yet, a zoomed picture) the pager fades
/// instead. `ViewerMotion` decides which phase the viewer is in and which move's completion still counts. A zoomed
/// picture does not close on a drag (a double tap returns it to size first), nor does one being pinched. An
/// accessibility container (`attachment-viewer`), so Close keeps its own identifier.
struct AttachmentViewerSheet: View {
    let selection: AttachmentSelection
    let loader: AttachmentLoader
    let hero: ViewerHero
    @Environment(\.dismiss) var dismiss
    @State private var index: Int
    @State private var pictures = LoadedPictures()
    @State var motion = ViewerMotion()
    /// 0 with the picture fitted to the screen, 1 with it on its tile in the chat.
    @State var progress: CGFloat = 1
    /// How far up or down the picture is dragged.
    @State var drag: CGFloat = 0
    /// The pictures zoomed in or being pinched, which a drag does not close.
    @State private var zoomedIDs: Set<String> = []
    @State var layout = ViewerPageLayout()
    /// The tile the way out aims at, in the window; it follows the tile if the chat moved under the closing picture.
    @State var landing: CGRect?

    private typealias Copy = AppBranding.Chat.Attachments

    init(selection: AttachmentSelection, loader: AttachmentLoader, hero: ViewerHero) {
        self.selection = selection
        self.loader = loader
        self.hero = hero
        _index = State(initialValue: selection.start)
    }

    var body: some View {
        let backdrop = ViewerGeometry.backdropOpacity(progress: progress, drag: drag)
        let drawsPicture = picture != nil && tile != nil
        ZStack {
            Color.black
                .opacity(backdrop)
                .ignoresSafeArea()
            pages
                .opacity(isOpen ? 1 : drawsPicture ? 0 : 1 - Double(progress))
                .offset(y: drawsPicture ? 0 : drag)
            GeometryReader { proxy in
                if !isOpen, drawsPicture { movingPicture(in: proxy) }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            VStack {
                controls
                Spacer()
            }
            .opacity(backdrop)
        }
        .gesture(ViewerDismissPan(isEnabled: canDrag, onChanged: dragged, onEnded: letGo))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.attachmentViewer)
        .accessibilityAction(.escape) { close() }
        .presentationBackground(.clear)
        .onAppear(perform: open)
        .onDisappear {
            if selection.media.contains(where: { $0.id == hero.shownID }) { hero.shownID = nil }
            hero.forgetPreloaded()
        }
        .onChange(of: index) { hero.shownID = current.id }
    }

    private var isOpen: Bool { motion.phase == .open }

    /// The picture on screen at its best: the full one decoded before the viewer opened or by its page, else the
    /// tile's thumbnail, else the one the page loaded for a picture behind "+N".
    private var picture: UIImage? {
        hero.preloaded[current.id] ?? layout.pictures[current.id] ?? hero.thumbnail(for: current.id)
            ?? layout.previews[current.id]
    }

    /// The tile to land on; none for a zoomed picture, which fades instead.
    var tile: TileGeometry? {
        zoomedIDs.contains(current.id) ? nil : hero.tiles[current.id]
    }

    /// The picture drawn by itself where `ViewerGeometry` puts it, in the full screen's coordinates, cut to what of it the
    /// chat would show near its tile (`ViewerGeometry.clip`).
    @ViewBuilder private func movingPicture(in proxy: GeometryProxy) -> some View {
        let space = proxy.frame(in: .global)
        if let picture, let tile {
            let toLocal = { (rect: CGRect) in rect.offsetBy(dx: -space.minX, dy: -space.minY) }
            let frame = ViewerGeometry(page: toLocal(layout.frames[current.id] ?? space),
                                       aspectRatio: picture.size.height > 0 ? picture.size.width / picture.size.height : nil,
                                       tile: TileGeometry(frame: toLocal(landing ?? tile.frame), radii: tile.radii),
                                       progress: progress,
                                       drag: drag)
            Image(uiImage: picture)
                .resizable()
                .scaledToFill()
                .frame(width: frame.rect.width, height: frame.rect.height)
                .clipShape(UnevenRoundedRectangle(cornerRadii: frame.radii))
                .position(x: frame.rect.midX, y: frame.rect.midY)
                .viewerViewportCut(progress: progress,
                                   viewport: hero.viewport.map(toLocal),
                                   screen: CGRect(origin: .zero, size: space.size))
                .accessibilityHidden(true)
        }
    }

    private var canDrag: Bool {
        motion.takesDrag && !zoomedIDs.contains(current.id)
    }

    var current: Attachment { selection.media[index] }

    private var pages: some View {
        TabView(selection: $index) {
            ForEach(Array(selection.media.enumerated()), id: \.element.id) { offset, attachment in
                page(attachment, isCurrent: offset == index)
                    .ignoresSafeArea()
                    .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
    }

    private func page(_ attachment: Attachment, isCurrent: Bool) -> some View {
        pageContent(attachment, isCurrent: isCurrent)
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }, action: { frame in
                layout.frames[attachment.id] = frame
            })
    }

    @ViewBuilder private func pageContent(_ attachment: Attachment, isCurrent: Bool) -> some View {
        if attachment.kind == .video {
            VideoPlayerPage(attachment: attachment,
                            message: selection.message,
                            loader: loader,
                            isCurrent: isCurrent,
                            poster: hero.thumbnail(for: attachment.id))
        } else {
            ImageViewerPage(attachment: attachment,
                            message: selection.message,
                            loader: loader,
                            preloaded: hero.preloaded[attachment.id],
                            thumbnail: hero.thumbnail(for: attachment.id),
                            onPreview: { layout.previews[attachment.id] = $0 },
                            onLoaded: { loaded in
                                pictures.byID[attachment.id] = loaded
                                layout.pictures[attachment.id] = loaded
                            },
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

/// Where each page lays its picture out and the full pictures the pages loaded, for the picture the viewer draws on its
/// way in and out. Written on every layout and load, so kept out of observation: nothing redraws for them, and the
/// viewer reads them when its own state moves.
final class ViewerPageLayout {
    var frames: [String: CGRect] = [:]
    var pictures: [String: UIImage] = [:]
    var previews: [String: UIImage] = [:]
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
