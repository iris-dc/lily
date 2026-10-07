import SwiftUI

/// A tournament in a list: type and status chips with the group's badge, the name, the place and distance, and how
/// many entries are in. Chips and the relative start share a row while they fit, like an event card's.
struct TournamentCard: View {
    let tournament: Tournament
    var distance: String?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                header
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(tournament.name).font(LilyTheme.Fonts.cardTitle)
                    PlaceLine(name: tournament.locationName, distance: distance)
                }
                EntriesBar(tournament: tournament)
            }
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                chips(badgeCapped: true)
                Spacer()
                relativeTime.multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                FlowLayout(spacing: DesignTokens.Spacing.sm, rowSpacing: DesignTokens.Spacing.sm) { chips(badgeCapped: false) }
                relativeTime
            }
        }
    }

    @ViewBuilder private func chips(badgeCapped: Bool) -> some View {
        EventTypeChip(type: tournament.type).fixedSize()
        TournamentStatusChip(status: tournament.status).fixedSize()
        if let group = tournament.group {
            GroupBadge(ref: group, capsWidth: badgeCapped)
        }
    }

    private var relativeTime: some View {
        Text(tournament.startsAt, format: .relative(presentation: .named))
            .font(LilyTheme.Fonts.caption)
            .foregroundStyle(.secondary)
    }
}

/// The status as a chip: the trophy before "Registration open", "In progress", "Completed" or "Cancelled".
struct TournamentStatusChip: View {
    let status: TournamentStatus

    var body: some View {
        Label(status.displayName, systemImage: DesignTokens.Symbols.tournament)
            .lilyChip(.regular)
    }
}

/// The card list alone: one `NavigationLink` per tournament, to its detail by id. The list sits at the screen margin
/// unless the container pads its content itself (a group's detail passes `horizontalPadding: 0`).
struct TournamentCardList: View {
    let tournaments: [Tournament]
    let distance: (Tournament) -> String?
    var horizontalPadding: CGFloat = DesignTokens.Layout.screenMargin

    var body: some View {
        LazyVStack(spacing: DesignTokens.Spacing.md) {
            ForEach(tournaments) { tournament in
                NavigationLink(value: tournament.destination) {
                    TournamentCard(tournament: tournament, distance: distance(tournament))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentRow(tournament.id))
            }
        }
        .padding(.horizontal, horizontalPadding)
    }
}

#Preview {
    ContentScreen {
        TournamentCard(tournament: MockTournamentFixtures.make(now: .now)[0].tournament).padding()
    }
}
