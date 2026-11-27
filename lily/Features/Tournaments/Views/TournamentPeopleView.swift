import SwiftUI

/// Opens the full entries list from the detail's People card. Carries the tournament's destination, so a stack
/// holding two details builds the right list from the value, whichever detail's registration answers the push.
nonisolated struct TournamentPeopleDestination: Hashable {
    let destination: TournamentDestination
}

/// Everyone in a tournament: the entries in seed order (`TournamentEntriesSegment`), each person opening their
/// profile, "Join team" on a team with room, and the organiser's removals asked about here. Reads the detail's own
/// view model, so an entry made there is already in the list.
struct TournamentPeopleView: View {
    let viewModel: TournamentDetailViewModel
    @State private var confirmation: TournamentConfirmation?

    private typealias Copy = AppBranding.Tournaments

    var body: some View {
        ContentScreen {
            ScrollView {
                if let detail = viewModel.shownDetail, !viewModel.isPreviewing {
                    TournamentEntriesSegment(viewModel: viewModel, detail: detail) { confirmation = .removeEntry($0) }
                        .padding(DesignTokens.Layout.detailMargin)
                        .readableColumn()
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(DesignTokens.Layout.detailMargin)
                }
            }
        }
        .navigationTitle(viewModel.tournament?.isTeam == true ? Copy.teamsSection : Copy.playersSection)
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarOnCompact()
        .task { await viewModel.loadIfNeeded() }
        .confirmationDialog(item: $confirmation,
                            title: { $0.title(name: viewModel.name) },
                            actions: { confirmationButton(for: $0) })
    }

    private func confirmationButton(for confirmation: TournamentConfirmation) -> some View {
        Button(role: confirmation.isDestructive ? .destructive : nil) {
            Task { await run(confirmation) }
        } label: {
            Text(confirmation.buttonTitle)
        }
    }

    /// Only the roster's own question reaches this dialog; the rest stay with the detail.
    private func run(_ confirmation: TournamentConfirmation) async {
        guard case .removeEntry(let entry) = confirmation else { return }
        await viewModel.removeEntry(entry)
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    let destination = MockTournamentFixtures.make(now: .now)[1].tournament.destination
    NavigationStack {
        TournamentPeopleView(viewModel: dependencies.makeTournamentDetailViewModel(for: destination) { _ in })
    }
}
