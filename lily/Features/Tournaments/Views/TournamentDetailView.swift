import SwiftUI

/// A tournament: chips, name and organiser, the winner once it is over, where it is hosted, its facts, the entries,
/// the bracket or the standings and the matches once it started, and the control the caller has. Fetched by id, so a
/// tile, a card, a room row, a chat's info button and a match reminder all open it the same way; a system row or a
/// reminder about a match opens it with that match's sheet up. The view model decides what the caller may do; this
/// draws it and hosts the sheets (edit, team name, match, invite, report) and confirmations.
struct TournamentDetailView: View {
    @State private var viewModel: TournamentDetailViewModel
    @State private var section: TournamentDetailSection = .entries
    @State private var presentedSheet: DetailSheet?
    @State private var confirmation: TournamentConfirmation?
    /// The match the destination named was raised once; a reload must not raise it again.
    @State private var hasShownLinkedMatch = false
    /// The scroll view's width, for the bracket's inset: the readable column's edge on a wide screen.
    @State private var contentWidth: CGFloat = 0
    @Environment(\.dismiss) private var dismiss
    private let dependencies: AppDependencies

    private typealias Copy = AppBranding.Tournaments

    private enum DetailSheet: Hashable, Identifiable {
        case edit, teamName, invite, report
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
                                   onInvite: { presentedSheet = .invite },
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
            showLinkedMatchIfNeeded()
        }
        // Deleted while on screen: there is nothing left to show here (a first load's 404 keeps its empty state).
        .onChange(of: viewModel.isGone) {
            if viewModel.isGone { dismiss() }
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
        case .invite:
            InvitePeopleSheet(viewModel: dependencies.makeTournamentInvitePeopleViewModel(for: viewModel.destination.id),
                              errorCenter: dependencies.errorCenter)
        case .report:
            ReportSheet(viewModel: dependencies.makeReportViewModel(for: viewModel.reportTarget, title: Copy.report),
                        errorCenter: dependencies.errorCenter)
        }
    }

    /// Everything sits in the readable column except a bracket, which keeps the whole width and scrolls under both
    /// screen edges, its first column lined up with the text above it.
    private func content(_ detail: TournamentDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    TournamentHeader(tournament: detail.tournament,
                                     organizerProfile: viewModel.organizerProfile,
                                     winnerName: viewModel.winnerName)
                    if let description = detail.tournament.description {
                        Text(description).font(.body)
                    }
                    TournamentFacts(tournament: detail.tournament)
                    if viewModel.showsEntries {
                        sectionPicker(detail.tournament)
                    }
                }
                .inReadableColumn()
                if viewModel.showsEntries {
                    segment(detail)
                }
                TournamentParticipationControl(viewModel: viewModel,
                                               onCreateTeam: { presentedSheet = .teamName },
                                               onLeave: { confirmation = .leave })
                    .inReadableColumn()
            }
            .padding(.vertical, DesignTokens.Spacing.xl)
        }
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { contentWidth = $0 }
        .refreshable { await viewModel.load() }
    }

    /// The bracket's columns start where the readable column does: the detail's margin on a phone, further in on a
    /// wide screen.
    private var bracketInset: CGFloat {
        max(DesignTokens.Spacing.xl, (contentWidth - DesignTokens.Layout.readableWidth) / 2 + DesignTokens.Spacing.xl)
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
                .inReadableColumn()
        case .results where detail.tournament.format == .singleElimination && !detail.matches.isEmpty:
            // `BracketView` undoes the margin itself and scrolls edge to edge; only its inset follows the column.
            results(detail, bracketInset: bracketInset)
                .padding(.horizontal, DesignTokens.Spacing.xl)
        case .results, .matches:
            results(detail, bracketInset: DesignTokens.Spacing.xl)
                .inReadableColumn()
        }
    }

    private func results(_ detail: TournamentDetail, bracketInset: CGFloat) -> some View {
        TournamentResultsSegment(section: section,
                                 detail: detail,
                                 viewModel: viewModel,
                                 onSelect: { presentedSheet = .match(id: $0.id) },
                                 bracketInset: bracketInset)
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
