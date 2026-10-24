import SwiftUI

/// The scrolling list of a chat: day chips, bubbles, system rows and the caller's unsent messages, anchored to the
/// bottom. Every scroll rule is `TranscriptScrollPolicy`'s, judged on each geometry report as a `Snapshot`. A tapped
/// quote scrolls to the original (loading older pages when it lies before the history held) and washes it in the accent
/// for a moment; pictures and videos open in `AttachmentViewerSheet` out of their tile, a file in QuickLook
/// once it is on the device; a long press on another member's bubble also offers Report and Block. While the reader
/// follows the bottom (the policy's state, which only the reader's own scroll ends), every report that changes the
/// content or the inset pins the end marker to the bottom; a reader of older messages is left where they are. A row
/// that arrives (`TranscriptArrivals`) grows from no height to its own on the arrival clock (`ChatRowView`), so with
/// each frame pinned the rows above move up with it, and nothing slides on its own; a sent message keeps its bubble's
/// row (`ChatRow.id`) and its height, so the confirmation swaps the bubble in place and moves nothing. Every report while
/// a row arrives, and in the first moments on screen, is logged at debug, and a line per arrival sums the motion up
/// (`ArrivalMotion`). A room the cache missed lays its first page out under a spinner and fades it in once the layout
/// has settled (`FirstPageReveal`).
struct ChatTranscript: View {
    let viewModel: ChatViewModel
    let dependencies: AppDependencies
    /// The id of the zero-height view after the rows, which a pin brings to the bottom.
    static let endMarkerID = "transcript-end"
    /// Bound to the bottom edge until the first pin; a pin binds it to the end marker.
    @State var position = ScrollPosition(edge: .bottom)
    @State var tracker = ScrollTracker()
    @State private var arrivals = ArrivalTracker()
    /// The message a tapped quote led to, while its wash shows.
    @State private var highlightedMessageID: String?
    /// The list's usable width, for the rows' fractions (`\.transcriptWidth`); `nil` before the first layout.
    @State private var transcriptWidth: CGFloat?
    /// The picture or video open full screen.
    @State private var viewing: AttachmentSelection?
    /// The tiles' places and thumbnails, which the viewer opens out of and closes into.
    @State private var hero: ViewerHero
    /// A tapped picture's full version on its way, before the viewer opens.
    @State private var opening: Task<Void, Never>?
    /// Whether the rows show yet: a room opened without its history shows its first page once it has settled.
    @State var firstPageReveal: FirstPageReveal
    /// The file open in QuickLook, as the preview copy the loader named.
    @State private var previewURL: URL?
    /// The message whose report sheet is open.
    @State private var reporting: ReportTarget?
    /// The row whose sender awaits the caller's word on a block.
    @State private var blocking: MessageRow?
    /// The public poll whose voters are on screen.
    @State private var votersOf: ChatMessage?
    /// The pin the bar shows, counted from the oldest; `nil` shows the newest.
    @State var shownPinIndex: Int?

    init(viewModel: ChatViewModel, dependencies: AppDependencies) {
        self.viewModel = viewModel
        self.dependencies = dependencies
        _hero = State(initialValue: ViewerHero(logger: viewModel.logger))
        _firstPageReveal = State(initialValue: FirstPageReveal(isShown: viewModel.room.hasHistory))
    }

    var body: some View {
        let rows = viewModel.rows
        let arrived = noteArrivals(in: rows)
        let lastRowArrived = rows.last.map { arrived.start(of: $0.id) != nil } ?? false
        ScrollView {
            // No spacing, so the end marker is the content's end and pins leave the last row where the padding puts it.
            VStack(spacing: 0) {
                LazyVStack(spacing: DesignTokens.Spacing.xs) {
                    olderPageSlot
                    ForEach(rows) { row in
                        ChatRowView(row: row,
                                    viewModel: viewModel,
                                    dependencies: dependencies,
                                    highlightedMessageID: highlightedMessageID,
                                    onTapQuote: reveal,
                                    onTapAttachment: openViewer,
                                    onOpenFile: { previewURL = $0 },
                                    onReport: { reporting = $0 },
                                    onBlock: { blocking = $0 },
                                    onShowVoters: { votersOf = $0 },
                                    arrivedAt: arrived.start(of: row.id))
                            .transition(MessageRemovalTransition(for: row))
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, DesignTokens.Layout.screenMargin)
                .padding(.vertical, DesignTokens.Spacing.md)
                // The content's end, which pins bring to the bottom and whose place says whether the reader is there:
                // never lazy, so the scroll view always knows where it is.
                Color.clear
                    .frame(height: 0)
                    .id(Self.endMarkerID)
                    .onGeometryChange(for: CGFloat.self,
                                      of: { $0.frame(in: .scrollView).minY },
                                      action: { tracker.endMarkerY = $0 })
            }
            .animation(.easeOut(duration: DesignTokens.Duration.fast)) { $0.opacity(firstPageReveal.isShown ? 1 : 0) }
        }
        .environment(\.viewerHero, hero)
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }, action: { hero.viewport = $0 })
        .overlay { spinner }
        .onChange(of: viewModel.isAwaitingHistory) { historyEnded() }
        .onArrival(perform: screenArrived, onDeparture: firstPageReveal.departed)
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .defaultScrollAnchor(.bottom, for: .alignment)
        .scrollPosition($position)
        .measuringTranscriptWidth($transcriptWidth)
        .onScrollGeometryChange(for: TranscriptScrollPolicy.Snapshot.self,
                                of: TranscriptScrollPolicy.Snapshot.init) { _, current in
            geometryChanged(to: current, laidOutRows: rows.count)
        }
        .onScrollGeometryChange(for: CGFloat.self,
                                of: { $0.containerSize.height + $0.contentInsets.top },
                                action: { _, line in tracker.composerLine = line })
        .onScrollPhaseChange { old, new in scrollPhaseChanged(from: old, to: new) }
        // Covered by another screen, the scroll view takes the keyboard's going without settling on the new bottom until
        // it is back on screen, in a frame the user sees: a transcript that left at the bottom comes back pinned to it.
        .onAppear {
            tracker.logsEveryReport(for: AppConfig.Chat.transcriptOpeningLogWindow)
            guard tracker.policy.isFollowing else { return }
            log("back on screen at the bottom, pinned")
            apply(.scrollToBottom)
        }
        .onDisappear { opening?.cancel() }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier(AccessibilityIdentifiers.chatList)
        // Outside the list's identifier, which would be stamped on the bar's buttons too; a bar, so the rows scrolling
        // under it blur as they do under the toolbar.
        .safeAreaBar(edge: .top, spacing: 0) { pinnedBar }
        .onChange(of: rows.count) { old, new in
            log("rows \(old) to \(new), the last \(lastRowArrived ? "arrived" : "loaded"), \(describe(tracker.geometry))")
        }
        .task(id: rows.last?.id) { [id = rows.last?.id] in
            await summarizeArrival(of: id)
        }
        .fullScreenCover(item: $viewing) { selection in
            AttachmentViewerSheet(selection: selection, loader: viewModel.attachmentLoader, hero: hero)
        }
        .attachmentQuickLook($previewURL)
        .sheet(item: $votersOf) { PollVotersSheet(message: $0, viewModel: viewModel, errorCenter: dependencies.errorCenter) }
        .sheet(item: $reporting) { target in
            ReportSheet(viewModel: dependencies.makeReportViewModel(for: target, title: AppBranding.Moderation.reportMessage),
                        errorCenter: dependencies.errorCenter)
        }
        .confirmationDialog(item: $blocking,
                            title: { AppBranding.Moderation.blockConfirmationTitle(name: $0.senderName) },
                            actions: blockButton(for:),
                            message: { _ in Text(AppBranding.Moderation.blockConfirmationMessage) })
    }

    /// The arrivals among `rows`, brought up to date while body runs (the first frame that draws an arriving row must
    /// know when it arrived), and the newest one watched for the log from the geometry last reported.
    /// The policy hears of the arrival here too, before the row's first layout.
    private func noteArrivals(in rows: [ChatRow]) -> TranscriptArrivals {
        let arrived = arrivals.update(to: rows,
                                      history: .init(isInFlight: viewModel.isLoadingHistory,
                                                     finished: viewModel.historyLoadsFinished))
        if let last = rows.last, arrived.start(of: last.id) != nil, tracker.watch(last.id) {
            tracker.policy.rowArrived(last)
        }
        return arrived
    }

    /// Opens the viewer once the picture's full version is decoded (or `viewerPreloadWait` has passed), so it opens
    /// sharp, and without the cover's slide: the viewer draws its own appearance over the chat. The composer gives the
    /// keyboard up first and the viewer waits for it to be gone: a cover only hides it, and it came back as the cover
    /// went, moving the whole chat under the picture that had just landed.
    private func openViewer(_ selection: AttachmentSelection) {
        opening?.cancel()
        opening = Task {
            let started = Date.now
            async let keyboard: Void = KeyboardDismissal.dismissAndWait(atMost: AppConfig.Chat.viewerKeyboardWait)
            await hero.preload(selection.current, in: selection.message, through: viewModel.attachmentLoader)
            await keyboard
            guard !Task.isCancelled else { return }
            opening = nil
            hero.log("presents \(selection.current.id) after \(Int(Date.now.timeIntervalSince(started) * 1000)) ms")
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { viewing = selection }
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

    func loadOlderPage() async {
        let loaded = await viewModel.loadOlder()
        if !loaded { tracker.policy.didNotLoadOlder() }
    }

    /// Scrolls to the quoted original once the view model has it on hand, then washes it for `messageHighlight`.
    func reveal(_ quote: ReplyQuote) {
        Task {
            guard await viewModel.revealQuoted(id: quote.messageId) else { return }
            log("scrolls to a quoted message")
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
    /// The geometry the policy judges: within `olderPageTriggerDistance` of the top (insets included) is near the top.
    /// Whether it is at the bottom is the end marker's to say (`ChatTranscript` sets it), never the reported height's.
    nonisolated init(_ geometry: ScrollGeometry) {
        let distanceFromTop = geometry.contentOffset.y + geometry.contentInsets.top
        self.init(offsetY: geometry.contentOffset.y,
                  contentHeight: geometry.contentSize.height,
                  bottomInset: geometry.contentInsets.bottom,
                  visibleHeight: geometry.containerSize.height,
                  isAtBottom: false,
                  isNearTop: distanceFromTop <= DesignTokens.Layout.olderPageTriggerDistance)
    }
}

/// The scroll state every geometry report mutates, held by reference so a tick never re-runs body (a value in `@State`
/// would), and the motion of the rows arriving, for the log.
@MainActor final class ScrollTracker {
    var policy = TranscriptScrollPolicy()
    var geometry = TranscriptScrollPolicy.Snapshot.empty
    /// The top of the end marker and of the composer, in the scroll view's frame: the content's end is on the composer
    /// when the marker is no lower than the composer's top.
    var endMarkerY: CGFloat = 0
    var composerLine: CGFloat = 0

    /// Whether the content's end is on screen above the composer, within `atBottomThreshold`.
    var endIsOnComposer: Bool {
        endMarkerY <= composerLine + DesignTokens.Layout.atBottomThreshold
    }
    /// The arrivals being watched, by row id; at most the newest and one it cut short.
    private(set) var motions: [String: ArrivalMotion] = [:]
    /// The newest row watched, so a later run of body does not watch it again once its summary is out.
    private var watchedRowID: String?
    /// Every report until then is logged: the transcript's first moments on screen, when estimates and insets settle.
    private var logsEveryReportUntil = Date.distantPast

    func logsEveryReport(for window: TimeInterval) {
        logsEveryReportUntil = .now + window
    }

    /// Whether this report goes to the log in full: a row is arriving, or the transcript has only just appeared.
    var logsThisReport: Bool {
        !motions.isEmpty || Date.now < logsEveryReportUntil
    }

    /// Starts watching the newest row's arrival from the geometry the transcript last reported. Called from body, which
    /// is the first to know a row arrived (the geometry report of its first layout may come before any `onChange`);
    /// repeated runs change nothing.
    /// Whether the row is new to the watch.
    @discardableResult
    func watch(_ rowID: String?) -> Bool {
        guard let rowID, rowID != watchedRowID else { return false }
        watchedRowID = rowID
        motions[rowID] = ArrivalMotion(rowID: rowID, offset: geometry.offsetY, contentHeight: geometry.contentHeight)
        return true
    }

    func record(_ snapshot: TranscriptScrollPolicy.Snapshot) {
        let now = Date.now
        for id in motions.keys {
            motions[id]?.record(offset: snapshot.offsetY, contentHeight: snapshot.contentHeight, at: now)
        }
    }

    func finishWatching(_ rowID: String) -> ArrivalMotion? {
        motions.removeValue(forKey: rowID)
    }
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
