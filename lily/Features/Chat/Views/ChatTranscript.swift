import SwiftUI

/// The scrolling list of a chat: day chips, bubbles, system rows and the caller's unsent messages, anchored to the
/// bottom. Every scroll rule is `TranscriptScrollPolicy`'s, judged on each geometry report as a `Snapshot`. A tapped
/// quote scrolls to the original (loading older pages when it lies before the history held) and washes it in the accent
/// for a moment; pictures and videos open in `AttachmentViewerSheet`, a file in QuickLook once it is on the device; a
/// long press on another member's bubble also offers Report and Block. A row appended at the bottom lands below the
/// fold (the anchor that keeps the bottom pinned through every other size change is lifted while the row arrives) and
/// the transcript slides down to it with the arrival's spring while the row fades and scales in
/// (`TranscriptArrivals` says which rows arrived, `ChatRowView` draws them from a clock); a sent message keeps its
/// bubble's row (`ChatRow.id`) and its height, so the confirmation swaps the bubble in place, moves nothing and leaves
/// the arrival running.
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
            let action = tracker.policy.geometryChanged(from: previous,
                                                        to: current,
                                                        hasRows: !rows.isEmpty,
                                                        canLoadOlder: viewModel.hasOlder && !viewModel.isLoadingOlder,
                                                        oldestID: viewModel.oldestID)
            // A pin puts the bottom where the anchor would hold it, so the anchor comes back with it.
            if action == .scrollToBottom { reanchor("by the pin") }
            if action != .none {
                let height = Int(current.contentHeight), offset = Int(current.offsetY), inset = Int(current.bottomInset)
                let geometry = "height \(height), offset \(offset), inset \(inset)"
                viewModel.logger.debug(.chat, "Transcript \(action) at \(geometry) in group \(viewModel.group.id)")
            }
            apply(action, lastRow: rows.last?.id)
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier(AccessibilityIdentifiers.chatList)
        .onChange(of: rows.last?.id, initial: true) { _, _ in
            tracker.policy.rowAppended(rows.last, isAtBottom: tracker.geometry.isAtBottom)
        }
        // The anchor is off while the newest row arrives and back once the arrival has settled, or sooner with a pin: a
        // size change in between must not pin the row before the slide reaches it. A task that wakes as a newer row
        // is appended leaves that row to its own task.
        .task(id: rows.last?.id) { [id = rows.last?.id] in
            guard (try? await Task.sleep(for: .seconds(MessageArrivalCurve.standard.settlingDuration))) != nil,
                  viewModel.rows.last?.id == id else { return }
            reanchor("after the arrival")
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

    private func apply(_ action: TranscriptScrollPolicy.Action, lastRow: String?) {
        switch action {
        case .none:
            break
        case .scrollToBottom:
            position.scrollTo(edge: .bottom)
            // A pin that moved nothing (the anchor had the bottom already) brings no report to release it. Set from a
            // geometry report, the pin is applied by this frame's follow-up layout, so a turn later is after it.
            Task { @MainActor in releaseLandedPosition() }
        case .animateToBottom:
            slide(to: lastRow)
        case .scrollTo(let y):
            position.scrollTo(y: y)
        case .loadOlder:
            tracker.policy.willLoadOlder(at: tracker.geometry, oldestID: viewModel.oldestID)
            Task { await loadOlder() }
        }
    }

    /// Puts the anchor back on the newest row, from a pin (the first settle's, one during an arrival) or the arrival's
    /// end; nothing to do when it is there already.
    private func reanchor(_ occasion: String) {
        let id = viewModel.rows.last?.id
        guard pinnedLastRowID != id else { return }
        pinnedLastRowID = id
        tracker.policy.anchorReturned()
        viewModel.logger.debug(.chat, "Transcript re-anchored \(occasion) in group \(viewModel.group.id)")
    }

    /// One slide per row, issued a turn after the geometry report that asked for it, where a scroll would land at once.
    /// On a position still bound to the bottom edge a scroll to that edge has no change to animate: a new row's slide
    /// frees the position first (cutting a slide still running short), while a later layout change of the same row (its
    /// second pass, a picture that loaded) rides on the binding, which keeps the bottom. The slide's completion releases
    /// the binding unless a newer row's slide owns it by then.
    private func slide(to row: String?) {
        if position.edge != nil {
            guard tracker.slidingRowID != row else { return }
            releaseLandedPosition()
        }
        tracker.slidingRowID = row
        Task { @MainActor in
            withAnimation(.messageArrival, completionCriteria: .logicallyComplete) {
                position.scrollTo(edge: .bottom)
            } completion: {
                if tracker.slidingRowID == row { releaseLandedPosition() }
            }
        }
    }

    /// A pin or a slide binds the position to the bottom edge, which would hold the bottom through the next appended
    /// row's layout; released once it has landed (a turn after a pin, at a slide's completion), a position bound to
    /// nothing leaves that row below the fold, where the policy's slide reaches it. Never while a slide runs, which a
    /// release cancels before its first frame, and never in the update that appends a row, after which the slide did
    /// not animate.
    private func releaseLandedPosition() {
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
    /// The row the latest slide was issued for.
    var slidingRowID: String?
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
