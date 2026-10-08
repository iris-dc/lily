import SwiftUI

/// The scrolling list of a chat: day chips, bubbles, system rows and the caller's unsent messages, anchored to the
/// bottom. The caller's own messages always scroll into view; others' only while the list is at the bottom, so
/// reading older messages is never interrupted. Scrolling near the top loads the page before and keeps what was on
/// screen where it was; `TranscriptScrollPolicy` holds those rules. A tap on a reply's quote scrolls to the original
/// (loading older pages when it lies before the history held) and washes it in the accent for a moment; a tap on a
/// picture or a video opens it full screen, a tap on a file opens it in QuickLook once it is on the device.
struct ChatTranscript: View {
    let viewModel: ChatViewModel
    let dependencies: AppDependencies
    @State private var position = ScrollPosition(edge: .bottom)
    @State private var policy = TranscriptScrollPolicy()
    @State private var geometry = TranscriptScrollPolicy.Snapshot.empty
    /// The message a tapped quote led to, while its wash shows.
    @State private var highlightedMessageID: String?
    /// The list's usable width, for the rows' fractions (`\.transcriptWidth`); `nil` before the first layout.
    @State private var transcriptWidth: CGFloat?
    /// The picture or video open full screen.
    @State private var viewing: AttachmentSelection?
    /// The file open in QuickLook, as the preview copy the loader named.
    @State private var previewURL: URL?

    /// A tapped picture or video with the message it belongs to (the viewer's link refresh needs both).
    private struct AttachmentSelection: Identifiable {
        let attachment: Attachment
        let message: ChatMessage

        var id: String { attachment.id }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.xs) {
                olderPageSlot
                ForEach(viewModel.rows) { row in
                    view(for: row)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, DesignTokens.Layout.screenMargin)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .defaultScrollAnchor(.bottom)
        .scrollPosition($position)
        .measuringTranscriptWidth($transcriptWidth)
        .onScrollGeometryChange(for: TranscriptScrollPolicy.Snapshot.self, of: Self.snapshot) { previous, current in
            geometry = current
            apply(policy.geometryChanged(from: previous,
                                         to: current,
                                         hasRows: !viewModel.rows.isEmpty,
                                         canLoadOlder: viewModel.hasOlder && !viewModel.isLoadingOlder))
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier(AccessibilityIdentifiers.chatList)
        .onChange(of: viewModel.rows.last?.id) { follow(viewModel.rows.last) }
        .fullScreenCover(item: $viewing) { selection in
            viewer(for: selection)
        }
        .attachmentQuickLook($previewURL)
    }

    @ViewBuilder private func viewer(for selection: AttachmentSelection) -> some View {
        if selection.attachment.kind == .video {
            VideoPlayerSheet(attachment: selection.attachment, message: selection.message, loader: viewModel.attachmentLoader)
        } else {
            ImageViewerSheet(attachment: selection.attachment, message: selection.message, loader: viewModel.attachmentLoader)
        }
    }

    @ViewBuilder private func view(for row: ChatRow) -> some View {
        switch row {
        case .day(let day):
            DaySeparator(day: day, now: viewModel.now())
        case .message(let messageRow):
            MessageBubble(row: messageRow,
                          profile: viewModel.profile(of: messageRow),
                          loader: viewModel.attachmentLoader,
                          isQuoteDeleted: messageRow.message.replyTo.map(viewModel.quoteIsDeleted) ?? false,
                          onTapQuote: reveal,
                          onTapAttachment: { viewing = AttachmentSelection(attachment: $0, message: messageRow.message) },
                          onOpenFile: { previewURL = $0 })
                .contextMenu { MessageContextMenu(row: messageRow, viewModel: viewModel) }
                .messageHighlight(highlightedMessageID == messageRow.message.id)
        case .system(let message):
            // Every chat is on the Chats stack, which registers the game and the tournament destinations.
            SystemMessageRow(message: message, viewModel: viewModel) { $0.open(through: dependencies.navigation) }
        case .pending(let pending):
            PendingMessageBubble(message: pending, viewModel: viewModel, onTapQuote: reveal)
        }
    }

    /// A fixed slot above the oldest row while there is a page before, so the spinner never shifts the content.
    @ViewBuilder private var olderPageSlot: some View {
        if viewModel.hasOlder {
            ProgressView()
                .opacity(viewModel.isLoadingOlder ? 1 : 0)
                .frame(height: DesignTokens.Layout.olderPageSlotHeight)
        }
    }

    private func apply(_ action: TranscriptScrollPolicy.Action) {
        switch action {
        case .none:
            break
        case .scrollToBottom:
            position.scrollTo(edge: .bottom)
        case .scrollTo(let y):
            position.scrollTo(y: y)
        case .loadOlder:
            policy.willLoadOlder(at: geometry)
            Task { await loadOlder() }
        }
    }

    private func loadOlder() async {
        let loaded = await viewModel.loadOlder()
        if !loaded { policy.didNotLoadOlder() }
    }

    /// Scrolls to the quoted original once the view model has it on hand, then washes it for `messageHighlight`.
    private func reveal(_ quote: ReplyQuote) {
        Task {
            guard await viewModel.revealQuoted(id: quote.messageId) else { return }
            withAnimation(.smooth(duration: DesignTokens.Duration.fast)) {
                position.scrollTo(id: quote.messageId, anchor: .center)
            }
            highlightedMessageID = quote.messageId
            try? await Task.sleep(for: .seconds(DesignTokens.Duration.messageHighlight))
            if highlightedMessageID == quote.messageId { highlightedMessageID = nil }
        }
    }

    nonisolated private static func snapshot(_ geometry: ScrollGeometry) -> TranscriptScrollPolicy.Snapshot {
        TranscriptScrollPolicy.Snapshot(
            offsetY: geometry.contentOffset.y,
            contentHeight: geometry.contentSize.height,
            bottomInset: geometry.contentInsets.bottom,
            isAtBottom: geometry.visibleRect.maxY >= geometry.contentSize.height - DesignTokens.Layout.atBottomThreshold,
            isNearTop: geometry.contentOffset.y + geometry.contentInsets.top <= DesignTokens.Layout.olderPageTriggerDistance
        )
    }

    private func follow(_ row: ChatRow?) {
        guard let row else { return }
        let isOwn = switch row {
        case .pending: true
        case .message(let messageRow): messageRow.isOwn
        case .day, .system: false
        }
        guard isOwn || geometry.isAtBottom else { return }
        withAnimation(.smooth(duration: DesignTokens.Duration.fast)) {
            position.scrollTo(edge: .bottom)
        }
    }
}

private extension View {
    /// The accent wash on the message a quote led to; animated in and out.
    func messageHighlight(_ isOn: Bool) -> some View {
        background(Color.lilyAccent.opacity(isOn ? DesignTokens.Opacity.messageHighlight : 0),
                   in: .rect(cornerRadius: DesignTokens.Radius.md))
            .animation(.easeOut(duration: DesignTokens.Duration.normal), value: isOn)
    }
}
