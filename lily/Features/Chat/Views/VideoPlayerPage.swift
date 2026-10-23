import AVKit
import SwiftUI

/// One page of `AttachmentViewerSheet`: the clip is downloaded through the `AttachmentLoader` (a ring shows the
/// progress; the cache answers at once for a clip seen before or just sent) and played from `previewFile`'s named copy,
/// since `AVPlayer` refuses the cache's extensionless file. It loads and plays only while `isCurrent`: the pager
/// instantiates a neighbour during a swipe, so a clip must not start behind a picture, and a page swiped away stops,
/// its download cancelled. The preview copy is removed with the player, or a hard link in tmp would keep a cleared
/// clip's bytes alive until iOS purges tmp.
struct VideoPlayerPage: View {
    let attachment: Attachment
    let message: ChatMessage
    let loader: AttachmentLoader
    let isCurrent: Bool
    /// The tile's thumbnail, drawn where the clip will play until it does.
    var poster: UIImage?
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
        } else {
            ZStack {
                if let poster {
                    Image(uiImage: poster)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if failed {
                    Image(systemName: DesignTokens.Symbols.videoPlaceholder)
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressRing(progress: progress, size: DesignTokens.Layout.downloadRingSize)
                }
            }
        }
    }

    /// A download that fails leaves the glyph; the loader logged why.
    private func load() async {
        do {
            let url = try await loader.previewFile(for: attachment, in: message) { progress = $0 }
            // Swiped away or closed while the download ran: no player nobody shows, and the copy nobody else would
            // remove goes now.
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

    /// Lets the player go, so no clip plays on or holds its file open behind another page, removes the preview copy and
    /// resets the ring for a return to this page.
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
