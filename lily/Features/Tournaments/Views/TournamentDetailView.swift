import SwiftUI

/// A tournament: chips, name and organiser, where it is hosted, its facts, the entries, the bracket or the standings
/// and the matches once it started, and the control the caller has. Fetched by id, so a tile, a card, a room row and
/// a chat's info button all open it the same way; a system row about a match opens it with that match's sheet up. The
/// view model decides what the caller may do; this draws it and hosts the sheets and confirmations.
struct TournamentDetailView: View {
    @State private var viewModel: TournamentDetailViewModel
    @State private var section: TournamentDetailSection = .entries
    @State private var presentedSheet: DetailSheet?
    @State private var confirmation: TournamentConfirmation?
    /// The match the destination named was raised once; a reload must not raise it again.
    @State private var hasShownLinkedMatch = false
    private let dependencies: AppDependencies

    private typealias Copy = AppBranding.Tournaments

    private enum DetailSheet: Hashable, Identifiable {
        case edit, teamName
        case match(id: String)

        var id: Self { self }
    }

    init(viewModel: TournamentDetailViewModel, dependencies: AppDependencies) {
        _viewModel = State(initialValue: viewModel)
        self.dependencies = dependencies
    }

    var body: some View {
        ContentScreen {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .loaded(let detail):
                content(detail)
            case .notFound:
                EmptyStateView(symbolName: DesignTokens.Symbols.tournament,
                               title: Copy.unavailable,
                               message: AppBranding.Groups.unavailableMessage)
            case .failed:
                EmptyStateView(symbolName: DesignTokens.Symbols.error,
                               title: Copy.loadFailedTitle,
                               message: AppBranding.Groups.loadFailedMessage,
                               actionTitle: AppBranding.Groups.tryAgain) {
                    Task { await viewModel.load() }
                }
            }
        }
        .navigationTitle(viewModel.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.showsMenu {
                ToolbarItem(placement: .topBarTrailing) {
                    TournamentMenu(viewModel: viewModel,
                                   onOpenChat: { Task { await viewModel.openChat() } },
                                   onStart: { confirmation = .start },
                                   onEdit: { presentedSheet = .edit },
                                   onCancel: { confirmation = .cancel })
                }
            }
        }
        .task {
            await viewModel.load()
            showLinkedMatchIfNeeded()
        }
        .sheet(item: $presentedSheet) { sheet($0) }
        .confirmationDialog(confirmationTitle, isPresented: isConfirming, titleVisibility: .visible, presenting: confirmation) {
            confirmationButton(for: $0)
        } message: { confirmation in
            if let tournament = viewModel.tournament, let message = confirmation.message(entries: tournament.entriesText) {
                Text(message)
            }
        }
    }

    @ViewBuilder private func sheet(_ sheet: DetailSheet) -> some View {
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
        }
    }

    private func content(_ detail: TournamentDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                TournamentHeader(tournament: detail.tournament, organizerProfile: viewModel.organizerProfile)
                if let description = detail.tournament.description {
                    Text(description).font(.body)
                }
                TournamentFacts(tournament: detail.tournament)
                if viewModel.showsEntries {
                    sectionPicker(detail.tournament)
                    segment(detail)
                }
                TournamentParticipationControl(viewModel: viewModel,
                                               onCreateTeam: { presentedSheet = .teamName },
                                               onLeave: { confirmation = .leave })
            }
            .padding(DesignTokens.Spacing.xl)
        }
        .refreshable { await viewModel.load() }
    }

    private func sectionPicker(_ tournament: Tournament) -> some View {
        Picker(Copy.tournament, selection: $section) {
            ForEach(TournamentDetailSection.allCases, id: \.self) { Text($0.title(for: tournament)).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier(AccessibilityIdentifiers.tournamentSection)
    }

    @ViewBuilder private func segment(_ detail: TournamentDetail) -> some View {
        switch section {
        case .entries:
            TournamentEntriesSegment(viewModel: viewModel, detail: detail) { confirmation = .removeEntry($0) }
        case .results, .matches:
            TournamentResultsSegment(section: section, detail: detail, viewModel: viewModel) {
                presentedSheet = .match(id: $0.id)
            }
        }
    }

    /// A system row about a match opened this screen: the Matches segment, with that match's sheet up, once.
    private func showLinkedMatchIfNeeded() {
        guard !hasShownLinkedMatch, let matchID = viewModel.destination.matchID,
              viewModel.detail?.match(id: matchID) != nil else { return }
        hasShownLinkedMatch = true
        section = .matches
        presentedSheet = .match(id: matchID)
    }

    private var confirmationTitle: String {
        confirmation?.title(name: viewModel.name) ?? ""
    }

    private var isConfirming: Binding<Bool> {
        Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } })
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
