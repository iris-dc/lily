import Foundation

/// What a tap on a gallery tile opens: the message's pictures and videos in the gallery's order (files are cards and
/// open through QuickLook), starting at the tapped one, or at the first hidden one from the "+N" tile, so every picture
/// of a message is reachable by paging.
nonisolated struct AttachmentSelection: Identifiable, Equatable, Sendable {
    let message: ChatMessage
    let media: [Attachment]
    let start: Int

    var id: String { media[start].id }
    var current: Attachment { media[start] }

    /// nil when the message has no picture or video, or `tile` names no tile drawn.
    init?(message: ChatMessage, tappedTile tile: Int) {
        let attachments = message.attachments
        let media = GalleryLayout.partition(attachments.map(\.kind)).media.map { attachments[$0] }
        let layout = GalleryLayout(count: media.count)
        guard !media.isEmpty, (0..<layout.shownCount).contains(tile) else { return nil }
        self.message = message
        self.media = media
        start = layout.showsOverflow(at: tile) ? GalleryLayout.maxTiles : tile
    }
}
