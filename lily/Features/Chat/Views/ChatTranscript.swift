import SwiftUI

/// The scrolling list of a chat: day chips, bubbles, system rows and the caller's unsent messages, anchored to the
/// bottom. Every scroll rule is `TranscriptScrollPolicy`'s, judged on each geometry report as a `Snapshot`. A tapped
/// quote scrolls to the original (loading older pages when it lies before the history held) and washes it in the accent
/// for a moment; pictures and videos open in `AttachmentViewerSheet`, a file in QuickLook once it is on the device; a
/// long press on another member's bubble also offers Report and Block. A row appended at the bottom lands below the
/// fold (the anchor that keeps the bottom pinned through every other size change is lifted for that one layout) and the
/// transcript slides down to it with the arrival's spring while the row fades and scales in (`TranscriptArrivals` says
/// which rows arrived, `ChatRowView` draws them from a clock); a sent message keeps its bubble's row (`ChatRow.id`) and
/// its height, so the confirmation swaps the bubble in place, moves nothing and leaves the arrival running.
struct ChatTranscript: View {
    let viewModel: ChatViewModel
    let dependencies: AppDependencies
    @State private var position = ScrollPosition(edge: .bottom)
    @State private var tracker = ScrollTracker()
    @State private var arrivals = ArrivalTracker()
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
        let arrived = arrivals.update(to: rows,
                                      history: .init(isInFlight: viewModel.isLoadingHistory,
                                                     finished: viewModel.historyLoadsFinished))
        let isAppending = tracker.policy.hasSettled && rows.last?.id != pinnedLastRowID
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.xs) {
                olderPageSlot
                ForEach(rows) { row in
                    ChatRowView(row: row,
                                viewModel: viewModel,
                                dependencies: dependencies,
                                highlightedMessageID: highlightedMessageID,
                                onTapQuote: reveal,
                                onTapAttachment: { viewing = $0 },
                                onOpenFile: { previewURL = $0 },
                                onReport: { reporting = $0 },
                                onBlock: { blocking = $0 },
                                arrivedAt: arrived.start(of: row.id))
                        .transition(MessageRemovalTransition(for: row))
                }
            }
            .scrollTargetLayout()
            // Animates a change of the last row only (a discarded bubble shrinking out, the layout around an appended
            // one): a prepended page or the first load keep the restore and the first pin exact, and both leave the last
            // row alone.
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
            if action == .none { unbindLandedPin() }
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
            // A pin that moved nothing (the anchor had the bottom already) brings no report to unbind it. Set from a
            // geometry report, the pin is applied by this frame's follow-up layout, so a turn later is after it; the
            // slide's scroll is issued from a Task, and an unbind the turn after that one cancelled it.
            Task { @MainActor in unbindLandedPin() }
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

    /// A pin leaves the position bound to the bottom edge, which would hold the bottom through the next append's layout;
    /// once the pin has landed, a position bound to nothing leaves the appended row below the fold, where the policy's
    /// slide reaches it.
    private func unbindLandedPin() {
        if tracker.geometry.isAtBottom, position.edge != nil {
            position = ScrollPosition()
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

/// The arrivals, held by reference and brought up to date while body runs: the first frame that draws an appended row
/// must already know when it arrived, and an `onChange` would run only after that frame, so the row would flash at full
/// strength before its fade. Unchanged rows leave the log as it is, so a second run of body changes nothing.
@MainActor private final class ArrivalTracker {
    private var log = TranscriptArrivals()

    func update(to rows: [ChatRow], history: TranscriptArrivals.HistoryLoads) -> TranscriptArrivals {
        log.update(to: rows.map(\.id),
                   at: .now,
                   history: history,
                   lasting: MessageArrivalCurve.standard.settlingDuration)
        return log
    }
}
