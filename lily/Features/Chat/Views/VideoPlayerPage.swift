import AVKit
import SwiftUI

/// One page of `AttachmentViewerSheet`: a video brought onto the device through the `AttachmentLoader` first (a ring
/// shows the download; the cache answers at once for a clip seen before or just sent) and then played from its named
/// file (`previewFile`: the cache's file has no extension, and `AVPlayer` refuses one) in the system player, so the
/// mock's `mock://` links play like the bucket's and a replay never costs egress again. The clip loads and plays only
/// while the page is the one on screen (`isCurrent`): the pager instantiates a neighbour during a swipe, so a clip
/// must not start behind a picture, and a page swiped away stops, a download in flight cancelled with it. The preview
/// copy goes with the player, as the QuickLook modifier removes its own (`QuickLookPreview`), because a hard link in
/// tmp would otherwise keep a cleared clip's bytes alive until iOS purges tmp.
struct VideoPlayerPage: View {
    let attachment: Attachment
    let message: ChatMessage
    let loader: AttachmentLoader
    let isCurrent: Bool
    @State private var player: AVPlayer?
    @State private var previewURL: URL?
    @State private var progress = 0.0
    @State private var failed = false

    var body: some View {
        content
            .task(id: isCurrent) {
                if isCurrent {
                    await load()
                } else {
                    stop()
                }
            }
            .onDisappear { stop() }
    }

    @ViewBuilder private var content: some View {
        if let player {
            VideoPlayer(player: player)
                .ignoresSafeArea()
                .accessibilityLabel(AppBranding.Chat.Attachments.video)
        } else if failed {
            Image(systemName: DesignTokens.Symbols.videoPlaceholder)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
        } else {
            ProgressRing(progress: progress, size: DesignTokens.Layout.downloadRingSize)
        }
    }

    /// A download that fails leaves the glyph; the loader logged why.
    private func load() async {
        do {
            let url = try await loader.previewFile(for: attachment, in: message) { progress = $0 }
            // The page may have been swiped away or closed by now (the download outlives it): a player nobody shows
            // must not start, and the copy nobody else would remove goes now.
            guard !Task.isCancelled else {
                PreviewFiles.remove(url)
                return
            }
            previewURL = url
            let player = AVPlayer(url: url)
            self.player = player
            player.play()
        } catch {
            guard !AppError.isCancellation(error) else { return }
            failed = true
        }
    }

    /// The player is let go with the page, so no clip keeps playing or its file open behind another page or the chat,
    /// and the preview copy with it; the ring starts afresh should the page come back.
    private func stop() {
        player?.pause()
        player = nil
        progress = 0
        if let previewURL {
            PreviewFiles.remove(previewURL)
            self.previewURL = nil
        }
    }
}
