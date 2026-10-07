import SwiftUI

/// Discover's cards with cursor paging, and the empty state around them. Scrolling and pull-to-refresh live here;
/// the screen owns the search field and the toolbar.
struct DiscoverGroupList: View {
    let viewModel: GroupListViewModel

    var body: some View {
        if viewModel.isInitialLoad {
            ProgressView()
        } else if viewModel.isDiscoverEmpty {
            refreshableScroll { nothingFoundState.containerRelativeFrame(.vertical) }
        } else {
            refreshableScroll { cards }
        }
    }

    /// The next page is asked for when the last card shows; `canLoadMore` keeps one request in flight at a time.
    private var cards: some View {
        LazyVStack(spacing: DesignTokens.Spacing.md) {
            ForEach(viewModel.groups) { group in
                NavigationLink(value: group) {
                    GroupCard(group: group, distance: viewModel.distanceText(for: group))
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
        .padding(.bottom, DesignTokens.Spacing.xxl)
    }

    private var nothingFoundState: EmptyStateView {
        EmptyStateView(symbolName: DesignTokens.Symbols.groups,
                       title: AppBranding.Groups.discoverEmptyTitle,
                       message: AppBranding.Groups.discoverEmptyMessage)
    }

    private func refreshableScroll(@ViewBuilder _ content: @escaping () -> some View) -> some View {
        RefreshableScroll(action: viewModel.refresh, content: content)
    }
}
