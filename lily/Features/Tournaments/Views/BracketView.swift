import SwiftUI

/// A bracket: one column per round, titled Final, Semi-finals and so on, scrolling sideways from screen edge to screen
/// edge; a later round's cell is centred on the two cells that feed it. Each cell opens the match sheet.
struct BracketView: View {
    let detail: TournamentDetail
    let viewModel: TournamentDetailViewModel
    let onSelect: (TournamentMatch) -> Void
    /// Where the first column starts and the last ends: the detail's margin, or the readable column's edge on a wide
    /// screen, so the bracket lines up with the text above it and still scrolls under both screen edges.
    var contentInset: CGFloat = DesignTokens.Spacing.xl

    private typealias Layout = DesignTokens.Layout

    var body: some View {
        let columns = BracketLayout.columns(of: detail.matches)
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: Layout.bracketColumnSpacing) {
                ForEach(Array(columns.enumerated()), id: \.offset) { index, matches in
                    column(matches, round: index + 1, of: columns.count)
                }
            }
        }
        .scrollIndicators(.hidden)
        // Undoes the detail's padding and puts the inset back as a content margin, so the columns scroll under the
        // screen edge.
        .padding(.horizontal, -DesignTokens.Spacing.xl)
        .contentMargins(.horizontal, contentInset, for: .scrollContent)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.tournamentBracket)
    }

    private func column(_ matches: [TournamentMatch], round: Int, of rounds: Int) -> some View {
        VStack(alignment: .leading, spacing: Layout.bracketCellSpacing) {
            RoundTitle(round: round, rounds: rounds, format: detail.tournament.format)
            ForEach(matches) { match in
                MatchButton(match: match, viewModel: viewModel, height: Layout.matchCellHeight, onSelect: onSelect)
                    .frame(height: BracketLayout.slotHeight(round: round,
                                                            cellHeight: Layout.matchCellHeight,
                                                            spacing: Layout.bracketCellSpacing))
            }
        }
        .frame(width: Layout.bracketColumnWidth)
    }
}
