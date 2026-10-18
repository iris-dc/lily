import SwiftUI

/// A tournament in a list: type and status chips with the group's badge, the name, the place and distance, and how
/// many entries are in. Chips and the relative start share a row while they fit, like an event card's.
struct TournamentCard: View {
    let tournament: Tournament
    var distance: String?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                CardHeader(startsAt: tournament.startsAt) { badgeCapped in chips(badgeCapped: badgeCapped) }
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(tournament.name).font(LilyTheme.Fonts.cardTitle)
                    PlaceLine(name: tournament.locationName, distance: distance)
                }
                EntriesBar(tournament: tournament)
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
}

/// The status as a chip: the trophy before "Registration open", "In progress", "Completed" or "Cancelled".
struct TournamentStatusChip: View {
    let status: TournamentStatus

    var body: some View {
        Label(status.displayName, systemImage: DesignTokens.Symbols.tournament)
            .lilyChip(.regular)
    }
}

/// The card list alone: one `NavigationLink` per tournament, to its detail with the card's copy as the preview. The
/// list sits at the screen margin unless the container pads its content itself (a group's detail passes `horizontalPadding: 0`).
struct TournamentCardList: View {
    let tournaments: [Tournament]
    let distance: (Tournament) -> String?
    var horizontalPadding: CGFloat = DesignTokens.Layout.screenMargin
    /// Inside a readable column (a group's detail) the list keeps one column on every width.
    var singleColumn = false

    var body: some View {
        AdaptiveCardGrid(data: tournaments, singleColumn: singleColumn) { tournament in
            NavigationLink(value: tournament.destination) {
                TournamentCard(tournament: tournament, distance: distance(tournament))
            }
            .buttonStyle(.plain)
            .lilyHoverable()
            .accessibilityIdentifier(AccessibilityIdentifiers.tournamentRow(tournament.id))
        }
        .padding(.horizontal, horizontalPadding)
    }
}

#Preview {
    ContentScreen {
        TournamentCard(tournament: MockTournamentFixtures.make(now: .now)[0].tournament).padding()
    }
}
