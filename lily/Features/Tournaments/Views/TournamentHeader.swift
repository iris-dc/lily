import SwiftUI

/// Top of the tournament detail: chips for type, format and status, the name, who organises it (a link to their
/// profile when the caller may open it) and where it is hosted.
struct TournamentHeader: View {
    let tournament: Tournament
    let organizerProfile: UserProfileDestination?

    private typealias Copy = AppBranding.Tournaments

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            FlowLayout(spacing: DesignTokens.Spacing.sm, rowSpacing: DesignTokens.Spacing.sm) {
                EventTypeChip(type: tournament.type)
                Label(tournament.format.displayName, systemImage: DesignTokens.Symbols.format).lilyChip(.regular)
                TournamentStatusChip(status: tournament.status)
            }
            titleBlock
            if let group = tournament.group {
                groupLine(group)
            }
        }
    }

    /// The title with "Organised by <name>" under it, a link to the organiser's profile when the caller may open it.
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            ScreenTitle(text: tournament.name)
            if let organizerProfile {
                NavigationLink(value: organizerProfile) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        ScreenSubtitle(text: Copy.organizedBy(name: tournament.organizerName))
                        Image(systemName: DesignTokens.Symbols.chevron)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentOrganizer)
            } else {
                ScreenSubtitle(text: Copy.organizedBy(name: tournament.organizerName))
            }
        }
    }

    /// "Hosted in <group>": a link to the group when it is public and live, its name alone otherwise.
    private func groupLine(_ group: EventGroupRef) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            if group.isLinkable {
                NavigationLink(value: group) {
                    Label(AppBranding.Groups.hostedIn(groupName: group.name), systemImage: DesignTokens.Symbols.groups)
                        .foregroundStyle(Color.lilyAccent)
                }
                .buttonStyle(.plain)
            } else {
                Label(AppBranding.Groups.hostedIn(groupName: group.name), systemImage: DesignTokens.Symbols.groups)
                    .foregroundStyle(.secondary)
            }
            if group.isPrivate {
                Text(AppBranding.Groups.membersOnly)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
    }
}

/// When it starts, when entries close, where, and how many entries are in.
struct TournamentFacts: View {
    let tournament: Tournament

    private static let dateStyle = Date.FormatStyle(date: .abbreviated, time: .shortened)

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Label {
                    Text(tournament.startsAt, format: Self.dateStyle)
                } icon: {
                    Image(systemName: DesignTokens.Symbols.time)
                }
                if let closes = tournament.registrationClosesAt, tournament.status == .registration {
                    Label {
                        Text(AppBranding.Groups.caption([AppBranding.Tournaments.registrationCloses,
                                                         closes.formatted(Self.dateStyle)]))
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
