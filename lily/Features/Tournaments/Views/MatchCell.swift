import SwiftUI

/// One match as a plain fill on the surface, never glass (a bracket draws dozens at once, and Liquid Glass is for the
/// controls): both sides with their seeds, the score or an en dash, the winner in ink and the loser faded, "Bye" or
/// "TBD" for an empty side, a flag while a dispute is open, and a faint accent border on the caller's own match. The list
/// variant adds the status and, when set, the time and place under the sides.
struct MatchCell: View {
    let match: TournamentMatch
    let viewModel: TournamentDetailViewModel
    /// The Matches list shows the status and the schedule; a bracket cell has no room for them.
    var showsDetails = false

    private typealias Copy = AppBranding.Tournaments
    private static let dateStyle = Date.FormatStyle(date: .abbreviated, time: .shortened)

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            side(match.entryAId, score: match.scoreA, flagged: match.isOpenDispute)
            side(match.entryBId, score: match.scoreB, flagged: false)
            if showsDetails {
                details
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lilySurface, in: .rect(cornerRadius: DesignTokens.Radius.md))
        .overlay {
            if viewModel.isMine(match) {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .strokeBorder(Color.lilyAccent.opacity(DesignTokens.Opacity.ownMatchStroke))
            }
        }
    }

    /// One side: seed, name, the flag (on the first side only) and the score.
    private func side(_ entryID: String?, score: Int?, flagged: Bool) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if let seed = viewModel.entry(entryID)?.seed {
                Text(String(seed))
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
            Text(name(of: entryID))
                .fontWeight(isWinner(entryID) ? .semibold : .regular)
                .lineLimit(1)
            Spacer(minLength: DesignTokens.Spacing.sm)
            if flagged {
                Image(systemName: DesignTokens.Symbols.disputed)
                    .foregroundStyle(Color.lilyAccent)
                    .accessibilityLabel(Copy.Match.disputed)
            }
            Text(score.map(String.init) ?? Copy.Match.noScore)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .monospacedDigit()
        .foregroundStyle(entryID == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.lilyInk))
        .opacity(isLoser(entryID) ? DesignTokens.Opacity.matchLoser : 1)
    }

    /// The status (an open dispute wins over it) and the schedule, in one caption line.
    private var details: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Text(match.isOpenDispute ? Copy.Match.disputed : Copy.Match.status(match.status))
                .foregroundStyle(match.isOpenDispute ? AnyShapeStyle(Color.lilyAccent) : AnyShapeStyle(.secondary))
            if let scheduledAt = match.scheduledAt {
                Label {
                    Text(scheduledAt, format: Self.dateStyle)
                } icon: {
                    Image(systemName: DesignTokens.Symbols.scheduled)
                }
            }
            if let place = match.location?.name {
                Label(place, systemImage: DesignTokens.Symbols.location)
            }
        }
        .font(LilyTheme.Fonts.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.top, DesignTokens.Spacing.xs)
    }

    private func name(of entryID: String?) -> String {
        if entryID == nil, match.status == .bye { return Copy.bye }
        return viewModel.entryName(entryID)
    }

    private func isWinner(_ entryID: String?) -> Bool {
        entryID != nil && match.winnerEntryId == entryID
    }

    private func isLoser(_ entryID: String?) -> Bool {
        entryID != nil && match.isDecided && match.winnerEntryId != entryID
    }
}

/// A cell as a `.plain` button opening the match sheet, identified `match-<id>`; the bracket fixes its height, the list
/// lets it grow with the details.
struct MatchButton: View {
    let match: TournamentMatch
    let viewModel: TournamentDetailViewModel
    var showsDetails = false
    var height: CGFloat?
    let onSelect: (TournamentMatch) -> Void

    var body: some View {
        Button {
            onSelect(match)
        } label: {
            MatchCell(match: match, viewModel: viewModel, showsDetails: showsDetails)
                .frame(height: height)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityIdentifiers.match(match.id))
    }
}

/// The caption over a round's matches: Final, Semi-finals, Quarter-finals, Round of 16, or Round N in a round robin.
struct RoundTitle: View {
    let round: Int
    let rounds: Int
    let format: TournamentFormat

    var body: some View {
        Text(BracketLayout.roundTitle(round: round, of: rounds, format: format))
            .font(LilyTheme.Fonts.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}
