import SwiftUI

/// A tournament: chips, name and organiser, where it is hosted, its facts, the entries and the control the caller has.
/// Fetched by id, so a tile, a card, a room row and a chat's info button all open it the same way. The view model
/// decides what the caller may do; this draws it and hosts the sheets and confirmations.
struct TournamentDetailView: View {
    @State private var viewModel: TournamentDetailViewModel
    @State private var section: TournamentDetailSection = .entries
    @State private var presentedSheet: DetailSheet?
    @State private var confirmation: Confirmation?
    private let dependencies: AppDependencies

    private typealias Copy = AppBranding.Tournaments

    private enum DetailSheet: String, Identifiable {
        case edit, teamName

        var id: String { rawValue }
    }

    /// A destructive action waiting for the caller's word.
    private enum Confirmation: Hashable, Identifiable {
        case cancel, leave
        case removeEntry(TournamentEntry)

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
                                   onEdit: { presentedSheet = .edit },
                                   onCancel: { confirmation = .cancel })
                }
            }
        }
        .task { await viewModel.load() }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .edit:
                if let tournament = viewModel.tournament {
                    EditTournamentSheet(viewModel: dependencies.makeEditTournamentViewModel(for: tournament,
                                                                                            onChange: viewModel.accept),
                                        errorCenter: dependencies.errorCenter)
                }
            case .teamName:
                TeamNameSheet(viewModel: viewModel, errorCenter: dependencies.errorCenter)
            }
        }
        .confirmationDialog(confirmationTitle, isPresented: isConfirming, titleVisibility: .visible, presenting: confirmation) {
            confirmationButton(for: $0)
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
            EmptyStateView(symbolName: section.symbolName,
                           title: section.title(for: detail.tournament),
                           message: Copy.resultsPending)
        }
    }

    private var confirmationTitle: String {
        switch confirmation {
        case .cancel: Copy.cancelConfirmation(name: viewModel.name)
        case .leave: Copy.leaveConfirmation(name: viewModel.name)
        case .removeEntry(let entry): Copy.removeEntryConfirmation(name: entry.name)
        case nil: ""
        }
    }

    private var isConfirming: Binding<Bool> {
        Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } })
    }

    private func confirmationButton(for confirmation: Confirmation) -> some View {
        Button(role: .destructive) {
            Task {
                switch confirmation {
                case .cancel: await viewModel.cancel()
                case .leave: await viewModel.leave()
                case .removeEntry(let entry): await viewModel.removeEntry(entry)
                }
            }
        } label: {
            switch confirmation {
            case .cancel: Text(Copy.cancel)
            case .leave: Text(Copy.leave)
            case .removeEntry: Text(Copy.removeEntry)
            }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    let destination = MockTournamentFixtures.make(now: .now)[0].tournament.destination
    NavigationStack {
        TournamentDetailView(viewModel: dependencies.makeTournamentDetailViewModel(for: destination) { _ in },
                             dependencies: dependencies)
    }
}
