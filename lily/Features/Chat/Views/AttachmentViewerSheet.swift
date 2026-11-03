import SwiftUI

/// One message's pictures and videos over black, paged from the tapped one in the gallery's order, so the ones behind a
/// "+N" tile are a swipe away; files stay cards that open in QuickLook. A picture page zooms (`ImageViewerPage`), a
/// video page plays only while it is on screen (`VideoPlayerPage`); Close, the "n / m" position and Share sit in glass
/// at the top. The cover leaves the chat in place (`presentationBackground(.clear)`, presented and taken away without
/// the cover's slide) and draws its own coming and going: the picture grows out of its tile to fill the screen as the
/// black comes in, and back onto the tile of the page on screen on Close, a drag far enough or VoiceOver's escape; a
/// video moves as its poster. On the way and while dragged the picture is drawn by itself over the hidden pager,
/// because a transformed pager re-laid its UIKit page out on alternate frames. The move is `ViewerHero`'s, run frame
/// by frame by `ViewerMoveDriver`, drawn by `ViewerMovingPicture` on both sides of the composer line (`ViewerStage`
/// below it), its phases `ViewerMotion`'s, the drag's rules `ViewerDismissal`'s. Without a picture or a tile (a page
/// with nothing loaded yet, a zoomed picture), or under Reduce Motion (`\.motion`), the pager fades instead, the drag
/// still following the finger. An accessibility container (`attachment-viewer`), so Close keeps its own identifier.
struct AttachmentViewerSheet: View {
    let selection: AttachmentSelection
    let loader: AttachmentLoader
    let hero: ViewerHero
    @Environment(\.dismiss) var dismiss
    @State private var index: Int
    @State private var pictures = LoadedPictures()
    @State var motion = ViewerMotion()
    /// Runs the moves frame by frame; a run in flight ends with the cover.
    @State var driver = ViewerMoveDriver()
    /// The pictures zoomed in or being pinched, which a drag does not close.
    @State private var zoomedIDs: Set<String> = []
    @State var layout = ViewerPageLayout()
    @Environment(\.motion) private var motionPreference

    private typealias Copy = AppBranding.Chat.Attachments

    init(selection: AttachmentSelection, loader: AttachmentLoader, hero: ViewerHero) {
        self.selection = selection
        self.loader = loader
        self.hero = hero
        _index = State(initialValue: selection.start)
    }

    var body: some View {
        let backdrop = ViewerGeometry.backdropOpacity(progress: hero.progress, drag: hero.drag)
        let drawsPicture = hero.moving != nil
        ZStack {
            ViewerBackdrop(hero: hero, layer: .overBars)
            pages
                .opacity(isOpen ? 1 : drawsPicture ? 0 : 1 - Double(hero.progress))
                .offset(y: drawsPicture ? 0 : hero.drag)
            if !isOpen {
                ViewerMovingPicture(hero: hero, layer: .overBars)
            }
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
            driver.cancel()
            // `leave()` has ended the move already on a close by the button; the fade and the interactive dismissal end here.
            hero.endMove()
        }
        .onChange(of: index) {
            hero.shownID = current.id
            stage()
        }
    }

    private var isOpen: Bool { motion.phase == .open }

    /// The picture on screen at its best: the full one decoded before the viewer opened or by its page, else the
    /// tile's thumbnail, else the one the page loaded for a picture behind "+N".
    private var picture: UIImage? {
        hero.preloaded[current.id] ?? pictures.byID[current.id] ?? hero.thumbnail(for: current.id)
            ?? layout.previews[current.id]
    }

    /// The tile to land on; none for a zoomed picture, which fades instead.
    var tile: TileGeometry? {
        zoomedIDs.contains(current.id) ? nil : hero.tiles[current.id]
    }

    /// Hands the chat and this cover the picture a move draws, from where its page lays it out; none when the pager
    /// fades instead.
    func stage() {
        let picture = picture
        guard ViewerMotion.movesPicture(hasPicture: picture != nil, hasTile: tile != nil, motion: motionPreference),
              let picture else {
            hero.moving = nil
            return
        }
        hero.moving = MovingPicture(id: current.id, image: picture, page: layout.frames[current.id])
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

/// Where each page lays its picture out and the previews loaded for the pictures behind "+N", for the picture the viewer
/// draws on its way in and out. Written on every layout and load, so kept out of observation: nothing redraws for them,
/// and the viewer reads them when its own state moves.
final class ViewerPageLayout {
    var frames: [String: CGRect] = [:]
    var previews: [String: UIImage] = [:]
}

/// The full pictures the pages loaded, by attachment id: Share offers the one on screen, and a move draws it. A
/// reference that the pages write, `ShareControl` reads in its body and the viewer's `stage()` reads outside any body
/// (action closures only, never `body`), so a picture finishing its load re-renders that control and never the pager:
/// a `TabView` re-rendered while its page controller is still settling can stick between two pages.
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
