import SwiftUI

/// The Matches segment: every match by round, each with its status and, when set, its time and place; a row opens the
/// match sheet.
struct MatchList: View {
    let detail: TournamentDetail
    let viewModel: TournamentDetailViewModel
    let onSelect: (TournamentMatch) -> Void

    var body: some View {
        let columns = BracketLayout.columns(of: detail.matches)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            ForEach(Array(columns.enumerated()), id: \.offset) { index, matches in
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    RoundTitle(round: index + 1, rounds: columns.count, format: detail.tournament.format)
                    ForEach(matches) { match in
                        MatchButton(match: match, viewModel: viewModel, showsDetails: true, onSelect: onSelect)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.tournamentMatches)
    }
}
