import SwiftUI

/// The items picked for the message, above the composer's field: `attachmentThumb` tiles that scroll sideways, a
/// picture as its thumbnail, a video as its thumbnail under a play badge, a file as a chip with its name and size,
/// each with its upload ring, a failed glyph that retries on tap, and an X. A container for the UI tests
/// (`chat-attachment-strip`), so the tiles and their buttons keep their own identifiers.
struct AttachmentStrip: View {
    let attachments: AttachmentComposerModel

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(attachments.drafts) { draft in
                    AttachmentDraftTile(draft: draft,
                                        onRemove: { attachments.remove(draft) },
                                        onRetry: { attachments.retry(draft) })
                }
            }
            // Room for the X, which pokes out of its tile's corner.
            .padding(.top, DesignTokens.Spacing.sm)
            .padding(.trailing, DesignTokens.Spacing.sm)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.chatAttachmentStrip)
    }
}

/// One picked item in the strip.
struct AttachmentDraftTile: View {
    let draft: AttachmentDraft
    let onRemove: () -> Void
    let onRetry: () -> Void

    private typealias Copy = AppBranding.Chat.Attachments
    private typealias Layout = DesignTokens.Layout

    var body: some View {
        preview
            .clipShape(.rect(cornerRadius: DesignTokens.Radius.quote))
            .overlay { stateOverlay }
            .overlay(alignment: .topTrailing) {
                removeButton.offset(x: Layout.stripBadgeSize / 2, y: -Layout.stripBadgeSize / 2)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityIdentifiers.chatAttachment(clientID: draft.id))
    }

    private var isPreparing: Bool { draft.state == .preparing }

    @ViewBuilder private var preview: some View {
        switch draft.kind {
        case .image:
            thumbnail
        case .video:
            thumbnail.overlay {
                if !isPreparing { PlayBadge(size: Layout.stripPlayBadgeSize) }
            }
        case .file:
            FileCard(info: FileCardInfo(fileName: draft.fileName, contentType: draft.contentType, sizeBytes: draft.sizeBytes),
                     own: false,
                     isPreparing: isPreparing)
                .background(Color.lilySurface)
                .frame(width: Layout.fileChipWidth, height: Layout.attachmentThumb)
        }
    }

    private var thumbnail: some View {
        LocalImage(url: draft.previewURL, isPreparing: isPreparing)
            .frame(width: Layout.attachmentThumb, height: Layout.attachmentThumb)
    }

    @ViewBuilder private var stateOverlay: some View {
        switch draft.state {
        case .uploading(let progress):
            ProgressRing(progress: progress)
        case .failed:
            Button(action: onRetry) {
                Image(systemName: DesignTokens.Symbols.failed)
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Copy.retryUpload)
        case .preparing, .uploaded:
            EmptyView()
        }
    }

    private var removeButton: some View {
        Button(action: onRemove) {
            Image(systemName: DesignTokens.Symbols.remove)
                .font(.system(size: Layout.stripBadgeSize))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.black.opacity(DesignTokens.Opacity.stripBadgeBacking))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Copy.remove)
        .accessibilityIdentifier(AccessibilityIdentifiers.chatAttachmentRemove(clientID: draft.id))
    }
}

/// A ring that fills clockwise with a transfer's progress, over the item it belongs to; `stripBadgeSize` on a strip
/// tile and a card, larger in the player while the clip comes.
struct ProgressRing: View {
    let progress: Double
    var size: CGFloat = DesignTokens.Layout.stripBadgeSize

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(DesignTokens.Opacity.stripBadgeBacking),
                        lineWidth: DesignTokens.Layout.progressRingWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: DesignTokens.Layout.progressRingWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .animation(.linear(duration: DesignTokens.Duration.fast), value: progress)
        .accessibilityHidden(true)
    }
}
