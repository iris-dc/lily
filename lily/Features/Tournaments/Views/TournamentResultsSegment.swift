import SwiftUI

/// The Bracket or Standings segment (by format) and the Matches segment of a tournament's detail: a short empty state
/// until the organiser started it, then the bracket, the table or the list. Drawn from the detail alone, so the intro's
/// miniature shows the same bracket.
struct TournamentResultsSegment: View {
    /// The Matches segment; `false` is the Bracket or Standings segment, by the tournament's format.
    let showsMatches: Bool
    let detail: TournamentDetail
    let onSelect: (TournamentMatch) -> Void
    /// Where the bracket's columns start; see `BracketView.contentInset`.
    var bracketInset: CGFloat = DesignTokens.Layout.detailMargin

    private var section: TournamentDetailSection { showsMatches ? .matches : .results }

    var body: some View {
        if detail.matches.isEmpty {
            EmptyStateView(symbolName: section.symbolName,
                           title: section.title(for: detail.tournament),
                           message: AppBranding.Tournaments.notStarted)
        } else if showsMatches {
            MatchList(detail: detail, onSelect: onSelect)
        } else if detail.tournament.format.drawsBracket {
            BracketView(detail: detail, onSelect: onSelect, contentInset: bracketInset)
        } else {
            StandingsTable(detail: detail)
        }
    }
}
