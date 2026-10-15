import SwiftUI

/// One match as a plain fill on the surface, never glass (a bracket draws dozens at once, and Liquid Glass is for the
/// controls): both sides with their seeds, the score or an en dash, the winner in ink and the loser faded (a draw fades
/// neither side), "Bye" or "TBD" for an empty side, a flag while a dispute is open, and a faint accent border on the
/// caller's own match. The list variant adds the status and, when set, the time and place under the sides (wrapping
/// when they do not fit one line); a bye's empty side already reads "Bye", so its caption is left out rather than
/// saying it twice.
struct MatchCell: View {
    let match: TournamentMatch
    /// The detail the match belongs to: the names and seeds of its sides, and whose entry the caller's is.
    let detail: TournamentDetail
    /// The Matches list shows the status and the schedule; a bracket cell has no room for them.
    var showsDetails = false

    private typealias Copy = AppBranding.Tournaments

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            side(match.entryAId, score: match.scoreA, flagged: match.isOpenDispute)
            side(match.entryBId, score: match.scoreB, flagged: false)
            if showsDetails, hasDetails {
                details
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lilySurface, in: .rect(cornerRadius: DesignTokens.Radius.md))
        .overlay {
            if detail.isMine(match) {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .strokeBorder(Color.lilyAccent.opacity(DesignTokens.Opacity.ownMatchStroke))
            }
        }
    }

    /// One side: seed, name, the flag (on the first side only) and the score.
    private func side(_ entryID: String?, score: Int?, flagged: Bool) -> some View {
        let outcome = match.outcome(for: entryID)
        return HStack(spacing: DesignTokens.Spacing.sm) {
            if let seed = detail.entry(entryID)?.seed {
                Text(String(seed))
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
            Text(name(of: entryID))
                .fontWeight(outcome == .won ? .semibold : .regular)
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
        .opacity(outcome == .lost ? DesignTokens.Opacity.matchLoser : 1)
    }

    /// A bye says so on its empty side; anything else has a status to caption.
    private var hasDetails: Bool { match.status != .bye || match.hasSchedule }

    /// The status (an open dispute wins over it) and the schedule as one caption: a row while the three fit, else the
    /// place wraps under the time, so a time and a long venue never truncate each other.
    private var details: some View {
        FlowLayout(spacing: DesignTokens.Spacing.md, rowSpacing: DesignTokens.Spacing.xs) {
            if match.status != .bye {
                Text(match.isOpenDispute ? Copy.Match.disputed : Copy.Match.status(match.status))
                    .foregroundStyle(match.isOpenDispute ? AnyShapeStyle(Color.lilyAccent) : AnyShapeStyle(.secondary))
            }
            if let scheduledAt = match.scheduledAt {
                Label {
                    Text(scheduledAt, format: LilyTheme.DateStyles.dateTime)
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
        return detail.entryName(entryID)
    }
}

/// A cell as a `.plain` button opening the match sheet, identified `match-<id>`; the bracket fixes its height, the list
/// lets it grow with the details.
struct MatchButton: View {
    let match: TournamentMatch
    let detail: TournamentDetail
    var showsDetails = false
    var height: CGFloat?
    let onSelect: (TournamentMatch) -> Void

    var body: some View {
        Button {
            onSelect(match)
        } label: {
            MatchCell(match: match, detail: detail, showsDetails: showsDetails)
                .frame(height: height)
        }
        .buttonStyle(.plain)
        .lilyHoverable()
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
