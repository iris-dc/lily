import SwiftUI

/// The inbox conversation: day chips and system cards anchored to the bottom like a chat, "Load earlier" above the
/// oldest item while a page before exists, and the empty state for a quiet inbox. Opening it marks everything read,
/// and so does an item that lands while it is open. The tab bar hides while it is open, as in a room.
struct InboxView: View {
    @State private var viewModel: InboxViewModel

    private typealias Copy = AppBranding.Inbox

    init(viewModel: InboxViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ContentScreen {
            list
                .overlay { placeholder }
        }
        .navigationTitle(Copy.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.hidden, for: .tabBar)
        .task { await viewModel.appear() }
        .onChange(of: viewModel.newestID) { Task { await viewModel.noteNewItems() } }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.md) {
                loadEarlierSlot
                ForEach(viewModel.rows) { row in
                    view(for: row)
                }
            }
            .padding(.horizontal, DesignTokens.Layout.screenMargin)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .defaultScrollAnchor(.bottom)
        .refreshable { await viewModel.refresh() }
    }

    @ViewBuilder private func view(for row: InboxTimelineRow) -> some View {
        switch row {
        case .day(let day):
            DaySeparator(day: day, now: viewModel.now())
        case .item(let item):
            InboxItemRow(item: item, viewModel: viewModel)
        }
    }

    /// A button rather than a scroll trigger: the inbox is short, and a tap never fights the bottom anchor.
    @ViewBuilder private var loadEarlierSlot: some View {
        if viewModel.hasOlder {
            Button(Copy.loadEarlier) { Task { await viewModel.loadOlder() } }
                .lilyGlassButton(sizing: .fitted, labelColor: .lilyInk)
                .disabled(viewModel.isLoadingOlder)
                .accessibilityIdentifier(AccessibilityIdentifiers.inboxLoadEarlier)
        }
    }

    /// A spinner while the first page loads; the empty or failed state for an inbox with nothing to show.
    @ViewBuilder private var placeholder: some View {
        if viewModel.rows.isEmpty {
            if viewModel.isInitialLoad {
                ProgressView()
            } else if viewModel.loadFailed {
                EmptyStateView(symbolName: DesignTokens.Symbols.error,
                               title: Copy.loadFailedTitle,
                               message: AppBranding.Events.loadFailedMessage)
            } else {
                EmptyStateView(symbolName: DesignTokens.Symbols.inbox, title: Copy.emptyTitle, message: Copy.emptyMessage)
            }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        InboxView(viewModel: dependencies.makeInboxViewModel())
    }
}
