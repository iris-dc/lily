import SwiftUI

/// When it starts, when entries close, where, the team size, where it is hosted, and how many entries are in: the
/// Details card of the tournament detail.
struct TournamentFacts: View {
    let tournament: Tournament

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Label {
                    Text(tournament.startsAt, format: LilyTheme.DateStyles.dateTime)
                } icon: {
                    Image(systemName: DesignTokens.Symbols.time)
                }
                if let closes = tournament.registrationClosesAt, tournament.status == .registration {
                    Label {
                        Text(AppBranding.Groups.caption([AppBranding.Tournaments.registrationCloses,
                                                         closes.formatted(LilyTheme.DateStyles.dateTime)]))
                    } icon: {
                        Image(systemName: DesignTokens.Symbols.registrationCloses)
                    }
                }
                Label(tournament.locationName, systemImage: DesignTokens.Symbols.location)
                if let group = tournament.group {
                    HostedInLine(group: group)
                }
                Label(AppBranding.Tournaments.Create.teamSize(tournament.teamSize), systemImage: DesignTokens.Symbols.team)
                EntriesBar(tournament: tournament)
            }
            .labelStyle(.iconColumn)
        }
    }
}

/// The line under the header once the tournament is over: "Winner: Marta" with the trophy in the accent, or the
/// cancelled notice; nothing while the tournament runs.
struct TournamentOutcomeLine: View {
    let tournament: Tournament
    /// The winning entry's name of a completed tournament; the line is left out without one.
    var winnerName: String?

    private typealias Copy = AppBranding.Tournaments

    var body: some View {
        if tournament.status == .completed, let winnerName {
            Label {
                Text(Copy.winner(winnerName))
            } icon: {
                Image(systemName: DesignTokens.Symbols.winner)
                    .foregroundStyle(Color.lilyAccent)
            }
            .font(.body.weight(.semibold))
            .accessibilityIdentifier(AccessibilityIdentifiers.tournamentWinner)
        } else if tournament.status == .cancelled {
            Text(Copy.cancelledNotice)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentScreen {
        TournamentFacts(tournament: MockTournamentFixtures.make(now: .now)[0].tournament)
            .padding()
    }
}
