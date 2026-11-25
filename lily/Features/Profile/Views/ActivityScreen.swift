import SwiftUI

/// The caller's own history, pushed from the profile root: the games they joined that have started and their finished
/// tournaments. Game rows are rows alone, as on a profile (a past game has no detail to open); tournament rows open
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
        case .loaded(let activity):
            RowsSection(title: Copy.pastGamesTitle, emptyNote: Copy.noPastGames, items: activity.events) {
                SharedEventRow(event: $0)
            }
            RowsSection(title: Copy.pastTournamentsTitle, emptyNote: Copy.noPastTournaments, items: activity.tournaments) {
                SharedTournamentRow(tournament: $0)
            }
        }
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
