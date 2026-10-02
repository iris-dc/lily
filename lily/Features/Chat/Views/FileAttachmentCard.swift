import SwiftUI

/// A file in a stored message's bubble: the type's glyph, the name, the size and, until the bytes are on the device, a
/// download glyph that becomes a ring while they come. A tap downloads through the `AttachmentLoader` when needed and
/// hands the named preview file up; the transcript opens it in QuickLook. A plain translucent fill inside the bubble's
/// own, never glass. A failed download leaves the card as it was; the loader logged why.
struct FileAttachmentCard: View {
    let attachment: Attachment
    let message: ChatMessage
    let loader: AttachmentLoader
    let own: Bool
    let onOpen: (URL) -> Void
    /// The share downloaded while a tap's download runs; `nil` otherwise.
    @State private var progress: Double?
    @State private var isCached = false

    private var info: FileCardInfo {
        FileCardInfo(fileName: attachment.fileName, contentType: attachment.contentType, sizeBytes: attachment.sizeBytes)
    }

    var body: some View {
        Button(action: open) {
            FileCard(info: info, own: own) { trailing }
        }
        .buttonStyle(.plain)
        .disabled(progress != nil)
        .task(id: attachment.id) { isCached = loader.cachedFile(for: attachment) != nil }
        .accessibilityLabel("\(info.displayName), \(info.sizeText())")
        .accessibilityHint(isCached ? "" : AppBranding.Chat.Attachments.download)
        .accessibilityIdentifier(AccessibilityIdentifiers.messageAttachmentFile(id: attachment.id))
    }

    @ViewBuilder private var trailing: some View {
        if let progress {
            ProgressRing(progress: progress)
        } else if !isCached {
            Image(systemName: DesignTokens.Symbols.download)
                .font(.title3)
        }
    }

    private func open() {
        Task {
            progress = 0
            defer { progress = nil }
            do {
                let url = try await loader.previewFile(for: attachment, in: message) { progress = $0 }
                isCached = true
                onOpen(url)
            } catch {
                guard !AppError.isCancellation(error) else { return }
            }
        }
    }
}

/// The shape every file shares, stored or picked: the type's glyph in a square, the name over the size, and a trailing
/// slot for the card's state. White on the caller's accent bubble, ink on everyone else's surface bubble and in the
/// strip, both as faint fills like a quote's.
struct FileCard<Trailing: View>: View {
    let info: FileCardInfo
    let own: Bool
    /// The preparer is still at work: a spinner stands where the size will be.
    var isPreparing = false
    @ViewBuilder let trailing: () -> Trailing

    private typealias Layout = DesignTokens.Layout

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: info.symbol)
                .font(.title3)
                .frame(width: Layout.fileIconSize, height: Layout.fileIconSize)
                .background(tint.opacity(DesignTokens.Opacity.quoteFill), in: .rect(cornerRadius: DesignTokens.Radius.quote))
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs / 2) {
                Text(verbatim: info.displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(Layout.fileNameLines)
                    .multilineTextAlignment(.leading)
                if isPreparing {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(tint)
                } else {
                    Text(info.sizeText())
                        .font(.caption)
                        .opacity(DesignTokens.Opacity.fileCaption)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
        .foregroundStyle(tint)
        .padding(DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(DesignTokens.Opacity.quoteFill), in: .rect(cornerRadius: DesignTokens.Radius.quote))
    }

    private var tint: Color { own ? .white : .lilyInk }
}

extension FileCard where Trailing == EmptyView {
    init(info: FileCardInfo, own: Bool, isPreparing: Bool = false) {
        self.init(info: info, own: own, isPreparing: isPreparing) { EmptyView() }
    }
}
