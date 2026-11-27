import SwiftUI

/// A tournament: its sport, name, format and status centered on top, the winner once it is over, the facts, the
/// People card (who organises it and who entered, the entries row opening the full list), the description, and the
/// bracket or the standings with the matches once it started. The join/leave control sits in the pinned bottom bar
/// with the chat and invite shortcuts. Fetched by id; an opener that holds the tournament (a card, a tile) hands it
/// over as the preview and the header, facts and control draw at once, the rest (a room row, the chat's info button,
/// a match reminder) shows the name until the detail answers; a system row or a reminder about a match opens it with
/// that match's sheet up. The chat is pushed on this stack, so Back returns here. The view model decides what the
/// caller may do; this draws it and hosts the sheets (edit, team name, match, invite, report) and confirmations.
struct TournamentDetailView: View {
    @State var viewModel: TournamentDetailViewModel
    @State var section: TournamentDetailSection = .results
    @State var presentedSheet: Sheet?
    @State var confirmation: TournamentConfirmation?
    /// The scroll view's width, for the bracket's inset: the readable column's edge on a wide screen.
    @State var contentWidth: CGFloat = 0
    @Environment(\.dismiss) private var dismiss
    let dependencies: AppDependencies

    typealias Copy = AppBranding.Tournaments

    /// The sheets the detail hosts.
    enum Sheet: Hashable, Identifiable {
        case edit, teamName, invite, report
        case match(id: String)

        var id: Self { self }
    }

    init(viewModel: TournamentDetailViewModel, dependencies: AppDependencies) {
        _viewModel = State(initialValue: viewModel)
        self.dependencies = dependencies
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        return ContentScreen {
            // One branch for the previewed and the loaded detail, so the scroll view keeps its identity (and its
            // offset) when the fetch answers.
            if let shown = viewModel.shownDetail {
                content(shown, isPreview: viewModel.isPreviewing)
            } else {
                emptyState
            }
        }
        .navigationTitle(viewModel.name)
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarOnCompact()
        .safeAreaInset(edge: .bottom) { actionBar }
        // This detail's entries ride its own view model, so an entry or removal made there reaches the People card
        // at once; another tournament's push (two details on one stack) builds a fresh one from the value.
        .navigationDestination(for: TournamentPeopleDestination.self) { people in
            if people.destination.id == viewModel.destination.id {
                TournamentPeopleView(viewModel: viewModel)
            } else {
                TournamentPeopleView(viewModel: dependencies.makeTournamentDetailViewModel(for: people.destination) { _ in
                    dependencies.tournamentChanges.recordChange()
                })
            }
        }
        .toolbar {
            if viewModel.permissions.showsMenu {
                ToolbarItem(placement: .topBarTrailing) {
                    TournamentMenu(viewModel: viewModel,
                                   onStart: { confirmation = .start },
                                   onEdit: { presentedSheet = .edit },
                                   onCancel: { confirmation = .cancel },
                                   onReport: { presentedSheet = .report })
                }
            }
        }
        // Re-runs on every tournament change made elsewhere (a live room event, a sibling screen); an own write is
        // acknowledged by the view model and costs no second request.
        .task(id: dependencies.tournamentChanges.version) {
            await viewModel.loadIfNeeded()
        }
        // The view model decides once per screen which match a system row or a reminder named, so Try again after an
        // offline first load still raises it, and the sheet never pops up at a later version bump.
        .onChange(of: viewModel.linkedMatchToShow, initial: true) { _, matchID in
            guard let matchID else { return }
            // A sheet the user opened from the preview meanwhile is not taken from under them.
            if presentedSheet == nil {
                section = .matches
                presentedSheet = .match(id: matchID)
            }
            viewModel.consumeLinkedMatch()
        }
        // Deleted while on screen: there is nothing left to show here (a first load's 404 keeps its empty state).
        .onChange(of: viewModel.isGone) {
            if viewModel.isGone { dismiss() }
        }
        .chatDestination(item: $viewModel.openedRoom, dependencies: dependencies)
        .sheet(item: $presentedSheet) { sheet($0) }
        .confirmationDialog(item: $confirmation, title: confirmationTitle(for:)) {
            confirmationButton(for: $0)
        } message: { confirmation in
            if let tournament = viewModel.tournament, let message = confirmation.message(entries: tournament.entriesText) {
                Text(message)
            }
        }
    }

    @ViewBuilder private func sheet(_ sheet: Sheet) -> some View {
        switch sheet {
        case .edit:
            if let tournament = viewModel.tournament {
                let editing = dependencies.makeEditTournamentViewModel(for: tournament, onChange: viewModel.accept)
                EditTournamentSheet(viewModel: editing, errorCenter: dependencies.errorCenter)
            }
        case .teamName:
            TeamNameSheet(viewModel: viewModel, errorCenter: dependencies.errorCenter)
        case .match(let id):
            MatchSheet(viewModel: viewModel, matchID: id, errorCenter: dependencies.errorCenter)
        case .invite:
            InvitePeopleSheet(viewModel: dependencies.makeTournamentInvitePeopleViewModel(for: viewModel.destination.id),
                              errorCenter: dependencies.errorCenter)
        case .report:
            ReportSheet(viewModel: dependencies.makeReportViewModel(for: viewModel.reportTarget, title: Copy.report),
                        errorCenter: dependencies.errorCenter)
        }
    }

    /// The states with nothing to draw yet: the spinner before an id-only open answers, "no longer available" and the
    /// failed first load with its Try again.
    @ViewBuilder private var emptyState: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
        case .notFound:
            EmptyStateView(symbolName: DesignTokens.Symbols.tournament,
                           title: Copy.unavailable,
                           message: AppBranding.Groups.unavailableMessage)
        case .failed:
            EmptyStateView.loadFailed(title: Copy.loadFailedTitle,
                                      message: AppBranding.Groups.loadFailedMessage,
                                      actionTitle: AppBranding.Groups.tryAgain) {
                Task { await viewModel.load() }
            }
        case .previewing, .loaded:
            EmptyView()
        }
    }

    private func confirmationTitle(for confirmation: TournamentConfirmation) -> String {
        confirmation.title(name: viewModel.name)
    }

    private func confirmationButton(for confirmation: TournamentConfirmation) -> some View {
        Button(role: confirmation.isDestructive ? .destructive : nil) {
            Task { await run(confirmation) }
        } label: {
            Text(confirmation.buttonTitle)
        }
    }

    /// The start shows the bracket or the standings as soon as the draw is in.
    private func run(_ confirmation: TournamentConfirmation) async {
        switch confirmation {
        case .cancel:
            await viewModel.cancel()
        case .leave:
            await viewModel.leave()
        case .start:
            await viewModel.start()
            if viewModel.hasMatches { section = .results }
        case .removeEntry(let entry):
            await viewModel.removeEntry(entry)
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    let destination = MockTournamentFixtures.make(now: .now)[1].tournament.destination
    NavigationStack {
        TournamentDetailView(viewModel: dependencies.makeTournamentDetailViewModel(for: destination) { _ in },
                             dependencies: dependencies)
    }
}
