import SwiftUI

/// The caller's own history, pushed from the profile root: the games they joined that have started and their finished
/// tournaments, each section folded to the latest few with "Show more" revealing the next batch and "Show less"
/// folding it back. Rows open the details through `EventDestination` and `TournamentDestination`, which the profile
/// sheet's stack registers; the game rows carry the "Ended" marker, since everything here is history.
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
                RowsSection(title: Copy.pastGamesTitle, emptyNote: Copy.noPastGames, items: viewModel.visibleGames) { event in
                    NavigationLink(value: EventDestination(id: event.id, name: event.title)) {
                        SharedEventRow(event: event, marksEnded: true)
                    }
                    .buttonStyle(.plain)
                    .lilyHoverable()
                }
                FoldControls(hasMore: viewModel.hasMoreGames,
                             canShowLess: viewModel.canShowLessGames,
                             moreIdentifier: AccessibilityIdentifiers.activityMoreGames,
                             lessIdentifier: AccessibilityIdentifiers.activityLessGames,
                             onMore: viewModel.showMoreGames,
                             onLess: viewModel.showLessGames)
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                RowsSection(title: Copy.pastTournamentsTitle,
                            emptyNote: Copy.noPastTournaments,
                            items: viewModel.visibleTournaments) {
                    SharedTournamentRow(tournament: $0)
                }
                FoldControls(hasMore: viewModel.hasMoreTournaments,
                             canShowLess: viewModel.canShowLessTournaments,
                             moreIdentifier: AccessibilityIdentifiers.activityMoreTournaments,
                             lessIdentifier: AccessibilityIdentifiers.activityLessTournaments,
                             onMore: viewModel.showMoreTournaments,
                             onLess: viewModel.showLessTournaments)
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

/// "Show more" and "Show less" under a folded section, at the rows' margin; both change the rows and themselves in
/// one frame (`withoutAnimation`), or the revealed rows land at once while the buttons drift after them.
private struct FoldControls: View {
    let hasMore: Bool
    let canShowLess: Bool
    let moreIdentifier: String
    let lessIdentifier: String
    let onMore: () -> Void
    let onLess: () -> Void

    var body: some View {
        if hasMore || canShowLess {
            HStack(spacing: DesignTokens.Spacing.xl) {
                if hasMore {
                    Button(AppBranding.Activity.showMore) { withoutAnimation(onMore) }
                        .lilyTextButton()
                        .accessibilityIdentifier(moreIdentifier)
                }
                if canShowLess {
                    Button(AppBranding.Groups.showLess) { withoutAnimation(onLess) }
                        .lilyTextButton()
                        .accessibilityIdentifier(lessIdentifier)
                }
            }
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
