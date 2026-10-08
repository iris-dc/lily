import SwiftUI

/// The attachments of a stored message: pictures and videos as `GalleryLayout` lays them out, each a thumbnail loaded
/// through the `AttachmentLoader`, and files as cards under the grid; a tap on a tile hands the attachment up and the
/// transcript opens the viewer or the player, a tap on a card downloads the file and hands its preview up.
struct AttachmentGallery: View {
    let message: ChatMessage
    let loader: AttachmentLoader
    let own: Bool
    let alignment: Alignment
    let onTap: (Attachment) -> Void
    let onOpenFile: (URL) -> Void

    var body: some View {
        let partition = GalleryLayout.partition(message.attachments.map(\.kind))
        VStack(alignment: alignment.horizontal, spacing: DesignTokens.Spacing.xs) {
            if !partition.media.isEmpty {
                GalleryGrid(layout: GalleryLayout(count: partition.media.count),
                            singleAspectRatio: message.attachments[partition.media[0]].aspectRatio,
                            alignment: alignment) { index in
                    tile(message.attachments[partition.media[index]])
                }
            }
            ForEach(partition.files, id: \.self) { index in
                FileAttachmentCard(attachment: message.attachments[index],
                                   message: message,
                                   loader: loader,
                                   own: own,
                                   onOpen: onOpenFile)
                    .galleryWidth(alignment: alignment)
            }
        }
    }

    @ViewBuilder private func tile(_ attachment: Attachment) -> some View {
        switch attachment.kind {
        case .image:
            ImageAttachmentView(attachment: attachment, message: message, loader: loader) { onTap(attachment) }
        case .video:
            VideoAttachmentView(attachment: attachment, message: message, loader: loader) { onTap(attachment) }
        case .file:
            EmptyView()
        }
    }
}

/// The attachments of an unsent message, from their files on the device: the pictures and videos as a grid, the files
/// as cards under it.
struct DraftGallery: View {
    let drafts: [AttachmentDraft]
    let alignment: Alignment

    var body: some View {
        let partition = GalleryLayout.partition(drafts.map(\.kind))
        VStack(alignment: alignment.horizontal, spacing: DesignTokens.Spacing.xs) {
            if !partition.media.isEmpty {
                GalleryGrid(layout: GalleryLayout(count: partition.media.count),
                            singleAspectRatio: drafts[partition.media[0]].aspectRatio,
                            alignment: alignment) { index in
                    DraftMediaTile(draft: drafts[partition.media[index]])
                }
            }
            ForEach(partition.files, id: \.self) { index in
                let draft = drafts[index]
                FileCard(info: FileCardInfo(fileName: draft.fileName, contentType: draft.contentType, sizeBytes: draft.sizeBytes),
                         own: true,
                         isPreparing: draft.state == .preparing)
                    .galleryWidth(alignment: alignment)
            }
        }
    }
}

/// A picked picture or video from its file, the video under a play badge once prepared.
struct DraftMediaTile: View {
    let draft: AttachmentDraft

    var body: some View {
        LocalImage(url: draft.previewURL, isPreparing: draft.state == .preparing)
            .overlay {
                if draft.kind == .video, draft.state != .preparing { PlayBadge(size: DesignTokens.Layout.playBadgeSize) }
            }
    }
}

/// Lays tiles out as `GalleryLayout` says, at `galleryWidthFraction` of the list: one picture fits its own aspect
/// ratio within `galleryMaxHeight` (a tall one gets narrower and keeps to `alignment`), the rest are squares in a
/// two-column `Grid`, a lone last tile spanning both columns, and the last tile of a longer gallery carries "+N".
struct GalleryGrid<Tile: View>: View {
    let layout: GalleryLayout
    /// Width over height of the one picture a single-tile gallery shows; square when unknown.
    let singleAspectRatio: CGFloat?
    let alignment: Alignment
    @ViewBuilder let tile: (Int) -> Tile

    private typealias Layout = DesignTokens.Layout

    var body: some View {
        Group {
            if layout.isSingle {
                single
            } else {
                grid
            }
        }
        .galleryWidth(alignment: alignment)
    }

    private var single: some View {
        tile(0)
            .aspectRatio(singleAspectRatio ?? 1, contentMode: .fit)
            .frame(maxHeight: Layout.galleryMaxHeight)
    }

    private var grid: some View {
        Grid(horizontalSpacing: Layout.gallerySpacing, verticalSpacing: Layout.gallerySpacing) {
            ForEach(layout.rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { index in
                        tile(index)
                            .aspectRatio(layout.spansRow(index) ? CGFloat(GalleryLayout.columns) : 1, contentMode: .fit)
                            .gridCellColumns(layout.spansRow(index) ? GalleryLayout.columns : 1)
                            .overlay { if layout.showsOverflow(at: index) { overflow } }
                    }
                }
            }
        }
    }

    private var overflow: some View {
        Color.black.opacity(DesignTokens.Opacity.galleryOverflowScrim)
            .overlay {
                Text(AppBranding.Chat.Attachments.more(layout.hiddenCount))
                    .font(LilyTheme.Fonts.sectionTitle)
                    .foregroundStyle(.white)
            }
            .allowsHitTesting(false)
    }
}

extension View {
    /// `galleryWidthFraction` of the list, hugging `alignment`: what lets `QuoteStack` measure a gallery (a flexible
    /// view would answer its ideal width, next to nothing) and keeps the bubble's padding plus another sender's avatar
    /// column inside `bubbleMaxWidthFraction` on every iPhone width. The grid and the file cards share it.
    func galleryWidth(alignment: Alignment) -> some View {
        transcriptFraction(DesignTokens.Layout.galleryWidthFraction, alignment: alignment)
    }
}

#Preview {
    ContentScreen {
        VStack(alignment: .trailing, spacing: DesignTokens.Spacing.md) {
            ForEach([1, 2, 3, 5], id: \.self) { count in
                GalleryGrid(layout: GalleryLayout(count: count), singleAspectRatio: 4 / 3, alignment: .trailing) { index in
                    Color.lilyAccent.opacity(0.3 + Double(index) * 0.15)
                }
                .clipShape(.rect(cornerRadius: DesignTokens.Radius.bubble))
            }
        }
        .padding()
    }
}
