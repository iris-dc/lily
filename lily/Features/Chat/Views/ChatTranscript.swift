import SwiftUI

/// The scrolling list of a chat: day chips, bubbles, system rows and the caller's unsent messages, anchored to the
/// bottom. Every scroll rule is `TranscriptScrollPolicy`'s, judged on each geometry report as a `Snapshot`. A tapped
/// quote scrolls to the original (loading older pages when it lies before the history held) and washes it in the accent
/// for a moment; pictures and videos open in `AttachmentViewerSheet`, a file in QuickLook once it is on the device; a
/// long press on another member's bubble also offers Report and Block. A row appended at the bottom lands below the
/// fold (the anchor that keeps the bottom pinned through every other size change is lifted for that one layout) and the
/// transcript slides down to it with the arrival's spring while the row fades and scales in (`MessageArrivalTransition`);
/// a sent message keeps its bubble's row (`ChatRow.id`), so the confirmation changes the bubble in place and moves
/// nothing.
struct ChatTranscript: View {
    let viewModel: ChatViewModel
    let dependencies: AppDependencies
    @State private var position = ScrollPosition(edge: .bottom)
    @State private var tracker = ScrollTracker()
    /// The last row of the layout the anchor last pinned; a different last row is an append in progress.
    @State private var pinnedLastRowID: String?
    /// The message a tapped quote led to, while its wash shows.
    @State private var highlightedMessageID: String?
    /// The list's usable width, for the rows' fractions (`\.transcriptWidth`); `nil` before the first layout.
    @State private var transcriptWidth: CGFloat?
    /// The picture or video open full screen.
    @State private var viewing: AttachmentSelection?
    /// The file open in QuickLook, as the preview copy the loader named.
    @State private var previewURL: URL?
    /// The message whose report sheet is open.
    @State private var reporting: ReportTarget?
    /// The row whose sender awaits the caller's word on a block.
    @State private var blocking: MessageRow?

    var body: some View {
        let rows = viewModel.rows
        let isAppending = tracker.policy.hasSettled && rows.last?.id != pinnedLastRowID
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.xs) {
                olderPageSlot
                ForEach(rows) { row in
                    view(for: row)
                        .transition(MessageArrivalTransition(for: row))
                }
            }
            .scrollTargetLayout()
            // Only an appended row animates: a prepended page or the first load keep the restore and the first pin
            // exact, and both leave the last row alone.
            .animation(tracker.policy.hasSettled ? .messageArrival : nil, value: rows.last?.id)
            .padding(.horizontal, DesignTokens.Layout.screenMargin)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .defaultScrollAnchor(.bottom, for: .alignment)
        .defaultScrollAnchor(isAppending ? nil : .bottom, for: .sizeChanges)
        .scrollPosition($position)
        .measuringTranscriptWidth($transcriptWidth)
        .onScrollGeometryChange(for: TranscriptScrollPolicy.Snapshot.self,
                                of: TranscriptScrollPolicy.Snapshot.init) { previous, current in
            tracker.geometry = current
            // The report after the append's layout: the row landed unanchored, the anchor may hold the bottom again. A
            // turn later: a state change here runs another layout in the same frame, and when the composer's inset
            // changed with the send (its text cleared), that layout would anchor the grown content to the bottom at once.
            if isAppending {
                Task { @MainActor in pinnedLastRowID = rows.last?.id }
            }
            let action = tracker.policy.geometryChanged(from: previous,
                                                        to: current,
                                                        hasRows: !rows.isEmpty,
                                                        canLoadOlder: viewModel.hasOlder && !viewModel.isLoadingOlder,
                                                        oldestID: viewModel.oldestID)
            apply(action)
            // A pin leaves the position bound to the bottom edge, which would hold the bottom through the next append's
            // layout; once the pin has landed, a position bound to nothing leaves the appended row below the fold, where
            // the policy's slide reaches it.
            if action == .none, current.isAtBottom, position.edge != nil {
                position = ScrollPosition()
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier(AccessibilityIdentifiers.chatList)
        // Re-pinned here only before the first settle; an append's re-pin waits for its layout (a state change here
        // would run body again before the layout and put the anchor back too early).
        .onChange(of: rows.last?.id, initial: true) { _, id in
            if !tracker.policy.hasSettled { pinnedLastRowID = id }
            tracker.policy.rowAppended(rows.last, isAtBottom: tracker.geometry.isAtBottom)
        }
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

    /// The bubble, with a context menu only when `MessageMenuItems` offers something: an empty menu would still open on
    /// a long press, and a tombstone offers nothing.
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
        case .animateToBottom:
            // Asked for from the geometry report of the layout that grew the content, where a scroll lands at once; a
            // turn later it is a change of its own and the spring applies.
            Task { @MainActor in
                withAnimation(.messageArrival) { position.scrollTo(edge: .bottom) }
            }
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
            let rowID = viewModel.rows.first { $0.messageID == quote.messageId }?.id ?? quote.messageId
            withAnimation(.smooth(duration: DesignTokens.Duration.fast)) {
                position.scrollTo(id: rowID, anchor: .center)
            }
            highlightedMessageID = quote.messageId
            try? await Task.sleep(for: .seconds(DesignTokens.Duration.messageHighlight))
            if highlightedMessageID == quote.messageId { highlightedMessageID = nil }
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
