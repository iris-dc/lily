import SwiftUI

/// A round robin's table as the backend ranks it: rank, name, played, won, drawn (while draws are allowed), lost,
/// score difference and points, the caller's row washed in the accent. Plain rows on the screen, no glass; each row is
/// one accessibility element, so VoiceOver and the UI tests read a line at a time.
struct StandingsTable: View {
    let detail: TournamentDetail
    let viewModel: TournamentDetailViewModel

    private typealias Copy = AppBranding.Tournaments.Standings
    private typealias Layout = DesignTokens.Layout

    private var showsDraws: Bool { detail.tournament.permitsDraws }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            header
            ForEach(detail.standings) { standing in
                row(standing)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.tournamentStandings)
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(verbatim: Copy.rank).frame(width: Layout.standingsRankWidth, alignment: .leading)
            Spacer(minLength: 0)
            stat(Copy.played)
            stat(Copy.won)
            if showsDraws {
                stat(Copy.drawn)
            }
            stat(Copy.lost)
            Text(verbatim: Copy.difference).frame(width: Layout.standingsDifferenceWidth, alignment: .trailing)
            Text(Copy.points).frame(width: Layout.standingsPointsWidth, alignment: .trailing)
        }
        .font(LilyTheme.Fonts.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, DesignTokens.Spacing.md)
    }

    private func row(_ standing: TournamentStanding) -> some View {
        let isMine = standing.entryId == detail.tournament.myEntryId
        return HStack(spacing: DesignTokens.Spacing.xs) {
            Text(String(standing.rank))
                .foregroundStyle(.secondary)
                .frame(width: Layout.standingsRankWidth, alignment: .leading)
            Text(viewModel.entryName(standing.entryId))
                .fontWeight(isMine ? .semibold : .regular)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            stat(String(standing.played))
            stat(String(standing.won))
            if showsDraws {
                stat(String(standing.drawn))
            }
            stat(String(standing.lost))
            Text(standing.scoreDifference.formatted(.number.sign(strategy: .always(includingZero: false))))
                .foregroundStyle(.secondary)
                .frame(width: Layout.standingsDifferenceWidth, alignment: .trailing)
            Text(String(standing.points))
                .fontWeight(.semibold)
                .frame(width: Layout.standingsPointsWidth, alignment: .trailing)
        }
        .font(.subheadline)
        .monospacedDigit()
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(isMine ? Color.lilyAccent.opacity(DesignTokens.Opacity.standingsHighlight) : .clear,
                    in: .rect(cornerRadius: DesignTokens.Radius.md))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityIdentifiers.standing(standing.entryId))
    }

    private func stat(_ text: String) -> some View {
        Text(text).frame(width: Layout.standingsStatWidth, alignment: .trailing)
    }
}
