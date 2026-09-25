import SwiftUI

/// The list under the Mine | Discover picker: conversation rows for Mine, cards with paging for Discover, and the
/// empty, failed and sign-in states around them. Scrolling and pull-to-refresh live here; the root owns the toolbar.
struct GroupListView: View {
    let viewModel: GroupListViewModel
    let content: GroupsContent
    let unread: UnreadCenter
    /// A Mine row was tapped; the root decides where it leads (the chat, or the group while chat is off).
    let onOpen: (SportGroup) -> Void
    let onSignIn: () -> Void

    private typealias Copy = AppBranding.Groups

    var body: some View {
        switch viewModel.scope {
        case .mine: mine
        case .discover: discover
        }
    }

    @ViewBuilder private var mine: some View {
        switch content {
        case .signInPrompt:
            signInPrompt
        case .myGroups where viewModel.isInitialLoad:
            ProgressView()
        case .myGroups where viewModel.groups.isEmpty:
            // Scrollable so the "pull to refresh" the failed state promises is possible from here.
            refreshableScroll { (viewModel.loadFailed ? loadFailedState : emptyState).containerRelativeFrame(.vertical) }
        case .myGroups:
            refreshableScroll { mineRows }
        }
    }

    @ViewBuilder private var discover: some View {
        if viewModel.isInitialLoad {
            ProgressView()
        } else if viewModel.isDiscoverEmpty {
            refreshableScroll { nothingFoundState.containerRelativeFrame(.vertical) }
        } else {
            refreshableScroll { discoverCards }
        }
    }

    private var mineRows: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.groups) { group in
                Button {
                    onOpen(group)
                } label: {
                    GroupRow(group: group, hasUnread: unread.hasUnread(groupID: group.id))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityIdentifiers.groupRow(group.id))
                Divider().padding(.leading, DesignTokens.Layout.avatarMedium + DesignTokens.Spacing.md)
            }
        }
        .padding(.horizontal, DesignTokens.Layout.screenMargin)
        .padding(.bottom, DesignTokens.Layout.floatingButtonFootprint)
    }

    /// The next page is asked for when the last card shows; `canLoadMore` keeps one request in flight at a time.
    private var discoverCards: some View {
        LazyVStack(spacing: DesignTokens.Spacing.md) {
            ForEach(viewModel.groups) { group in
                NavigationLink(value: group) {
                    GroupCard(group: group)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityIdentifiers.groupRow(group.id))
                .onAppear {
                    if group.id == viewModel.groups.last?.id, viewModel.canLoadMore {
                        Task { await viewModel.loadMore() }
                    }
                }
            }
            if viewModel.isLoadingMore {
                ProgressView().padding(DesignTokens.Spacing.lg)
            }
        }
        .padding(.horizontal, DesignTokens.Layout.screenMargin)
        .padding(.bottom, DesignTokens.Layout.floatingButtonFootprint)
    }

    private var signInPrompt: some View {
        EmptyStateView(symbolName: DesignTokens.Symbols.groups,
                       title: AppBranding.guestProfileTitle,
                       message: Copy.guestMineMessage,
                       actionTitle: AppBranding.signInAction,
                       action: onSignIn)
    }

    private var emptyState: EmptyStateView {
        EmptyStateView(symbolName: DesignTokens.Symbols.groups, title: Copy.emptyTitle, message: Copy.emptyMessage)
    }

    private var nothingFoundState: EmptyStateView {
        EmptyStateView(symbolName: DesignTokens.Symbols.groups,
                       title: Copy.discoverEmptyTitle,
                       message: Copy.discoverEmptyMessage)
    }

    private var loadFailedState: EmptyStateView {
        EmptyStateView(symbolName: DesignTokens.Symbols.error,
                       title: Copy.loadFailedTitle,
                       message: AppBranding.Events.loadFailedMessage)
    }

    /// The one place that declares the pull-to-refresh gesture and what it reloads.
    private func refreshableScroll(@ViewBuilder _ content: () -> some View) -> some View {
        ScrollView { content() }
            .refreshable { await viewModel.refresh() }
    }
}
