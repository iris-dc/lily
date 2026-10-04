import SwiftUI

/// The Bracket or Standings segment (by format) and the Matches segment of a tournament's detail: a short empty state
/// until the organiser started it, then the bracket, the table or the list.
struct TournamentResultsSegment: View {
    let section: TournamentDetailSection
    let detail: TournamentDetail
    let viewModel: TournamentDetailViewModel
    let onSelect: (TournamentMatch) -> Void

    var body: some View {
        if detail.matches.isEmpty {
            EmptyStateView(symbolName: section.symbolName,
                           title: section.title(for: detail.tournament),
                           message: AppBranding.Tournaments.notStarted)
        } else {
            switch section {
            case .results where detail.tournament.format == .roundRobin:
                StandingsTable(detail: detail, viewModel: viewModel)
            case .results:
                BracketView(detail: detail, viewModel: viewModel, onSelect: onSelect)
            case .matches:
                MatchList(detail: detail, viewModel: viewModel, onSelect: onSelect)
            case .entries:
                EmptyView()
            }
        }
    }
}
