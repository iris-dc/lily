import SwiftUI

/// Every public tournament open for entries, pushed from the carousel's "See all": the cards soonest first, with
/// distances, and a type dropdown in the toolbar. Works for guests; a card opens the tournament's detail.
struct DiscoverTournamentsView: View {
    @State private var viewModel: TournamentListViewModel
    private let dependencies: AppDependencies

    private typealias Copy = AppBranding.Tournaments

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: dependencies.makeTournamentListViewModel(scope: .upcoming))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ContentScreen {
            content
        }
        .navigationTitle(Copy.discoverTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                TypeFilterButton(typeFilter: $viewModel.typeFilter, identifier: AccessibilityIdentifiers.tournamentsTypeFilter)
            }
        }
        // Re-runs on a change made elsewhere; the position first, so the one request is ranked by distance.
        .task(id: dependencies.tournamentChanges.version) {
            await viewModel.loadUserLocation()
            await viewModel.loadIfStale()
        }
    }

    @ViewBuilder private var content: some View {
        if viewModel.isInitialLoad {
            ProgressView()
        } else if viewModel.visibleTournaments.isEmpty {
            refreshableScroll {
                emptyState.readableColumn().containerRelativeFrame(.vertical)
            }
        } else {
            refreshableScroll {
                TournamentCardList(tournaments: viewModel.visibleTournaments, distance: viewModel.distanceText)
                    .padding(.vertical, DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.xxl)
            }
        }
    }

    private var emptyState: EmptyStateView {
        if viewModel.loadFailed {
            EmptyStateView(symbolName: DesignTokens.Symbols.error,
                           title: Copy.loadFailedTitle,
                           message: AppBranding.Events.loadFailedMessage)
        } else if viewModel.typeFilter != nil {
            EmptyStateView(symbolName: DesignTokens.Symbols.tournament,
                           title: AppBranding.Groups.discoverEmptyTitle,
                           message: Copy.discoverEmptyMessage)
        } else {
            EmptyStateView(symbolName: DesignTokens.Symbols.tournament, title: Copy.emptyTitle, message: Copy.emptyMessage)
        }
    }

    private func refreshableScroll(@ViewBuilder _ content: @escaping () -> some View) -> some View {
        ScrollView { content() }
            .refreshable { await viewModel.load() }
    }
}

#Preview {
    NavigationStack {
        DiscoverTournamentsView(dependencies: .makeMock())
    }
}
