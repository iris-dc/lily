import AVKit
import SwiftUI

/// A video full screen over black: the clip is brought onto the device through the `AttachmentLoader` first (a ring
/// shows the download; the cache answers at once for a clip seen before or just sent) and then plays from its named
/// file (`previewFile`: the cache's file has no extension, and `AVPlayer` refuses one) in the system player, so the
/// mock's `mock://` links play like the bucket's and a replay never costs egress again. The preview copy goes with the
/// sheet, as the QuickLook modifier removes its own (`QuickLookPreview`), because a hard link in tmp would otherwise
/// keep a cleared clip's bytes alive until iOS purges tmp. Close at the top in a glass circle, like the picture viewer,
/// under the same identifiers.
struct VideoPlayerSheet: View {
    let attachment: Attachment
    let message: ChatMessage
    let loader: AttachmentLoader
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var previewURL: URL?
    @State private var progress = 0.0
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
            VStack {
                closeButton
                Spacer()
            }
        }
        .task { await load() }
        .onDisappear { stop() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.attachmentViewer)
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

    private var closeButton: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: DesignTokens.Symbols.dismiss)
            }
            .lilyGlassIconButton()
            .accessibilityLabel(AppBranding.Chat.Attachments.close)
            .accessibilityIdentifier(AccessibilityIdentifiers.attachmentViewerClose)
            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
    }

    /// A download that fails leaves the glyph; the loader logged why.
    private func load() async {
        do {
            let url = try await loader.previewFile(for: attachment, in: message) { progress = $0 }
            // The sheet may be gone by now (the download outlives it): a player nobody shows must not start, and the
            // copy nobody else would remove goes now.
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

    /// The player is let go with the sheet, so no clip keeps playing or its file open behind the chat, and the preview
    /// copy with it.
    private func stop() {
        player?.pause()
        player = nil
        if let previewURL {
            PreviewFiles.remove(previewURL)
            self.previewURL = nil
        }
    }
}
