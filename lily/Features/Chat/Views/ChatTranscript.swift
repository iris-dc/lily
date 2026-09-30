import SwiftUI

/// The scrolling list of a chat: day chips, bubbles, system rows and the caller's unsent messages, anchored to the
/// bottom. The caller's own messages always scroll into view; others' only while the list is at the bottom, so
/// reading older messages is never interrupted. Scrolling near the top loads the page before and keeps what was on
/// screen where it was; `TranscriptScrollPolicy` holds those rules.
struct ChatTranscript: View {
    let viewModel: ChatViewModel
    let dependencies: AppDependencies
    @State private var position = ScrollPosition(edge: .bottom)
    @State private var policy = TranscriptScrollPolicy()
    @State private var geometry = TranscriptScrollPolicy.Snapshot.empty

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
    }

    @ViewBuilder private func view(for row: ChatRow) -> some View {
        switch row {
        case .day(let day):
            DaySeparator(day: day, now: viewModel.now())
        case .message(let messageRow):
            MessageBubble(row: messageRow, profile: viewModel.profile(of: messageRow))
                .contextMenu { MessageContextMenu(message: messageRow.message, viewModel: viewModel) }
        case .system(let message):
            // Every chat is on the Chats stack, which owns that stack's one `SportEvent` destination.
            SystemMessageRow(message: message, viewModel: viewModel) { dependencies.navigation.openInChat($0) }
        case .pending(let pending):
            PendingMessageBubble(message: pending, viewModel: viewModel)
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
