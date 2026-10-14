import SwiftUI

/// The scrolling list of a chat: day chips, bubbles, system rows and the caller's unsent messages, anchored to the
/// bottom. Every scroll rule is `TranscriptScrollPolicy`'s, judged on the geometry as a `Snapshot`: the caller's own
/// messages always scroll into view, others' only while the list is at the bottom, so reading older messages is never
/// interrupted; scrolling near the top loads the page before and keeps what was on screen where it was. A tap on a
/// reply's quote scrolls to the original (loading older pages when it lies before the history held) and washes it in
/// the accent for a moment; a tap on a picture or a video opens the message's pictures and videos full screen, paged
/// from the tapped one (`AttachmentViewerSheet`), a tap on a file opens it in QuickLook once it is on the device. A long
/// press on another member's bubble also offers Report, which opens the report sheet over that message, and Block, which
/// asks first and then hides the sender's lines in every room.
struct ChatTranscript: View {
    let viewModel: ChatViewModel
    let dependencies: AppDependencies
    @State private var position = ScrollPosition(edge: .bottom)
    @State private var tracker = ScrollTracker()
    /// The message a tapped quote led to, while its wash shows.
    @State private var highlightedMessageID: String?
    /// The list's usable width, for the rows' fractions (`\.transcriptWidth`); `nil` before the first layout.
    @State private var transcriptWidth: CGFloat?
    /// The tapped picture or video open full screen, as the selection its tile handed up.
    @State private var viewing: AttachmentSelection?
    /// The file open in QuickLook, as the preview copy the loader named.
    @State private var previewURL: URL?
    /// The message whose report sheet is open, as the target the view model framed.
    @State private var reporting: ReportTarget?
    /// The row whose sender awaits the caller's word on a block.
    @State private var blocking: MessageRow?

    var body: some View {
        let rows = viewModel.rows
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.xs) {
                olderPageSlot
                ForEach(rows) { row in
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
        .onScrollGeometryChange(for: TranscriptScrollPolicy.Snapshot.self,
                                of: TranscriptScrollPolicy.Snapshot.init) { previous, current in
            tracker.geometry = current
            apply(tracker.policy.geometryChanged(from: previous,
                                                 to: current,
                                                 hasRows: !rows.isEmpty,
                                                 canLoadOlder: viewModel.hasOlder && !viewModel.isLoadingOlder,
                                                 oldestID: viewModel.oldestID))
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier(AccessibilityIdentifiers.chatList)
        .onChange(of: rows.last?.id) { follow(rows.last) }
        .fullScreenCover(item: $viewing) { selection in
            AttachmentViewerSheet(selection: selection, loader: viewModel.attachmentLoader)
        }
        .attachmentQuickLook($previewURL)
        .sheet(item: $reporting) { target in
            ReportSheet(viewModel: dependencies.makeReportViewModel(for: target, title: AppBranding.Moderation.reportMessage),
                        errorCenter: dependencies.errorCenter)
        }
        .confirmationDialog(item: $blocking,
                            title: { AppBranding.Moderation.blockConfirmationTitle(name: $0.senderName) },
                            actions: blockButton(for:),
                            message: { _ in Text(AppBranding.Moderation.blockConfirmationMessage) })
    }

    @ViewBuilder private func view(for row: ChatRow) -> some View {
        switch row {
        case .day(let day):
            DaySeparator(day: day, now: viewModel.now())
        case .message(let messageRow):
            messageBubble(for: messageRow)
        case .system(let message):
            // Every chat is on the Chats stack, which registers the game and the tournament destinations.
            SystemMessageRow(message: message, viewModel: viewModel) { $0.open(through: dependencies.navigation) }
        case .pending(let pending):
            PendingMessageBubble(message: pending, viewModel: viewModel, onTapQuote: reveal)
        }
    }

    /// The bubble with its context menu, attached only when `MessageMenuItems` holds something to tap, so a long press
    /// on a tombstone opens nothing (the caller's own has no item, another member's tombstone offers neither Report nor
    /// Block). Report frames the message as the sheet's target, Block holds the row until the caller confirms.
    @ViewBuilder private func messageBubble(for messageRow: MessageRow) -> some View {
        let message = messageRow.message
        let items = MessageMenuItems.items(for: message,
                                           isOwn: messageRow.isOwn,
                                           canReply: viewModel.canReply(to: message),
                                           canDelete: viewModel.canDelete(message))
        let bubble = MessageBubble(row: messageRow,
                                   profile: viewModel.profile(of: messageRow),
                                   loader: viewModel.attachmentLoader,
                                   isQuoteDeleted: message.replyTo.map(viewModel.quoteIsDeleted) ?? false,
                                   onTapQuote: reveal,
                                   onTapAttachment: { viewing = $0 },
                                   onOpenFile: { previewURL = $0 })
            .messageHighlight(highlightedMessageID == message.id)
        if items.hasEnabledItems {
            bubble.contextMenu {
                MessageContextMenu(items: items,
                                   row: messageRow,
                                   viewModel: viewModel,
                                   onReport: { reporting = viewModel.reportTarget(for: message) },
                                   onBlock: { blocking = messageRow })
            }
        } else {
            bubble
        }
    }

    /// The block confirmation's one action: blocks the row's sender for the caller, in every room at once.
    private func blockButton(for row: MessageRow) -> some View {
        Button(AppBranding.Moderation.block, role: .destructive) {
            Task { await viewModel.block(senderOf: row.message) }
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
            tracker.policy.willLoadOlder(at: tracker.geometry, oldestID: viewModel.oldestID)
            Task { await loadOlder() }
        }
    }

    private func loadOlder() async {
        let loaded = await viewModel.loadOlder()
        if !loaded { tracker.policy.didNotLoadOlder() }
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

    /// Scrolls an appended row into view when the policy says so, animated (the first pin in `apply` is not).
    private func follow(_ row: ChatRow?) {
        let action = TranscriptScrollPolicy.rowAppended(row, isAtBottom: tracker.geometry.isAtBottom)
        guard case .scrollToBottom = action else { return }
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

extension TranscriptScrollPolicy.Snapshot {
    /// The geometry the policy judges, with the thresholds applied: within `atBottomThreshold` of the content end is at
    /// the bottom, within `olderPageTriggerDistance` of the top (insets included) is near the top.
    nonisolated init(_ geometry: ScrollGeometry) {
        let visibleBottom = geometry.visibleRect.maxY
        let distanceFromTop = geometry.contentOffset.y + geometry.contentInsets.top
        self.init(offsetY: geometry.contentOffset.y,
                  contentHeight: geometry.contentSize.height,
                  bottomInset: geometry.contentInsets.bottom,
                  isAtBottom: visibleBottom >= geometry.contentSize.height - DesignTokens.Layout.atBottomThreshold,
                  isNearTop: distanceFromTop <= DesignTokens.Layout.olderPageTriggerDistance)
    }
}

/// The scroll state every geometry report mutates, held by reference so a tick never re-runs body (a value in `@State`
/// would).
@MainActor private final class ScrollTracker {
    var policy = TranscriptScrollPolicy()
    var geometry = TranscriptScrollPolicy.Snapshot.empty
}
