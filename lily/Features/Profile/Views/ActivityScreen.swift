import SwiftUI

/// The caller's own history, pushed from the profile root: the games they joined that have started and their finished
/// tournaments, each section folded to the latest few with "Show more" revealing the next batch. Game rows are rows
/// alone, as on a profile (a past game has no detail to open); tournament rows open
/// the detail through `TournamentDestination`, which the profile sheet's stack registers.
struct ActivityScreen: View {
    @State private var viewModel: ActivityViewModel

    private typealias Copy = AppBranding.Activity

    init(viewModel: ActivityViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ContentScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    content
                }
                .padding(.vertical, DesignTokens.Spacing.xl)
                .readableColumn()
            }
        }
        .navigationTitle(Copy.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    /// One spinner, or one retry, for both lists.
    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.lg)
        case .failed:
            loadFailed
        case .loaded:
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                RowsSection(title: Copy.pastGamesTitle, emptyNote: Copy.noPastGames, items: viewModel.visibleGames) {
                    SharedEventRow(event: $0)
                }
                if viewModel.hasMoreGames {
                    showMoreButton(AccessibilityIdentifiers.activityMoreGames) { viewModel.showMoreGames() }
                }
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                RowsSection(title: Copy.pastTournamentsTitle,
                            emptyNote: Copy.noPastTournaments,
                            items: viewModel.visibleTournaments) {
                    SharedTournamentRow(tournament: $0)
                }
                if viewModel.hasMoreTournaments {
                    showMoreButton(AccessibilityIdentifiers.activityMoreTournaments) { viewModel.showMoreTournaments() }
                }
            }
        }
    }

    /// Reveals a folded section's next batch; ink, at the rows' margin.
    private func showMoreButton(_ identifier: String, action: @escaping () -> Void) -> some View {
        Button(Copy.showMore, action: action)
            .lilyTextButton()
            .accessibilityIdentifier(identifier)
            .padding(.horizontal, DesignTokens.Layout.screenMargin)
    }

    /// The popup said what went wrong; the screen offers the retry.
    private var loadFailed: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            SectionNote(text: Copy.loadFailedTitle)
            Button(AppBranding.Groups.tryAgain) { Task { await viewModel.load() } }
                .lilyGlassButton(sizing: .fitted, controlSize: .regular, labelColor: .lilyInk)
                .padding(.horizontal, DesignTokens.Layout.screenMargin)
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        ActivityScreen(viewModel: dependencies.makeActivityViewModel())
    }
}
