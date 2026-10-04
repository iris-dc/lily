import SwiftUI

/// The Tournaments segment of a group's detail: its tournaments as cards, or why there are none. The detail owns the
/// scroll view, the refresh and the loads; this draws the list view model's state inside the detail's margins.
struct GroupTournamentsSegment: View {
    let viewModel: TournamentListViewModel

    private typealias Copy = AppBranding.Tournaments

    var body: some View {
        if viewModel.isInitialLoad {
            ProgressView().frame(maxWidth: .infinity)
        } else if viewModel.visibleTournaments.isEmpty {
            viewModel.loadFailed ? loadFailedState : emptyState
        } else {
            TournamentCardList(tournaments: viewModel.visibleTournaments, distance: viewModel.distanceText, horizontalPadding: 0)
        }
    }

    private var emptyState: EmptyStateView {
        EmptyStateView(symbolName: DesignTokens.Symbols.tournament, title: Copy.emptyTitle, message: Copy.groupEmptyMessage)
    }

    private var loadFailedState: EmptyStateView {
        EmptyStateView(symbolName: DesignTokens.Symbols.error,
                       title: Copy.loadFailedTitle,
                       message: AppBranding.Events.loadFailedMessage)
    }
}
