import SwiftUI

/// Top of the tournament detail: chips for type, format and status, the name, who organises it (a link to their
/// profile when the caller may open it), the outcome once the tournament is over (the winner with the trophy, or that
/// it was cancelled) and where it is hosted.
struct TournamentHeader: View {
    let tournament: Tournament
    let organizerProfile: UserProfileDestination?
    /// The winning entry's name of a completed tournament; the line is left out without one.
    var winnerName: String?

    private typealias Copy = AppBranding.Tournaments

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            FlowLayout(spacing: DesignTokens.Spacing.sm, rowSpacing: DesignTokens.Spacing.sm) {
                EventTypeChip(type: tournament.type)
                Label(tournament.format.displayName, systemImage: DesignTokens.Symbols.format).lilyChip(.regular)
                TournamentStatusChip(status: tournament.status)
            }
            OwnerTitleBlock(title: tournament.name,
                            subtitle: Copy.organizedBy(name: tournament.organizerName),
                            destination: organizerProfile,
                            identifier: AccessibilityIdentifiers.tournamentOrganizer)
            outcome
            if let group = tournament.group {
                HostedInLine(group: group)
            }
        }
    }

    /// "Winner: Marta" in the accent under the title, or the cancelled notice; nothing while the tournament runs.
    @ViewBuilder private var outcome: some View {
        if tournament.status == .completed, let winnerName {
            Label(Copy.winner(winnerName), systemImage: DesignTokens.Symbols.winner)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.lilyAccent)
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentWinner)
        } else if tournament.status == .cancelled {
            Text(Copy.cancelledNotice)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// When it starts, when entries close, where, and how many entries are in.
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
                Label(AppBranding.Tournaments.Create.teamSize(tournament.teamSize), systemImage: DesignTokens.Symbols.team)
                EntriesBar(tournament: tournament)
            }
            .labelStyle(.iconColumn)
        }
    }
}

#Preview {
    ContentScreen {
        VStack(spacing: DesignTokens.Spacing.xl) {
            TournamentHeader(tournament: MockTournamentFixtures.make(now: .now)[0].tournament, organizerProfile: nil)
            TournamentFacts(tournament: MockTournamentFixtures.make(now: .now)[0].tournament)
        }
        .padding()
    }
}
