import SwiftUI

/// A game two people both joined: the sport in the mark, the title, and when and where it was. A profile shows it as
/// a row alone; Activity wraps it in a link to the detail and marks the caption "Ended", everything there being over.
struct SharedEventRow: View {
    let event: EventSummary
    var marksEnded = false

    var body: some View {
        GroupRowContent(name: event.title,
                        visibility: nil,
                        caption: marksEnded ? event.endedCaption : event.caption,
                        hasUnread: false,
                        avatarSymbol: event.type.symbolName,
                        markTint: .sport)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(AccessibilityIdentifiers.sharedEventRow(event.id))
    }
}

/// A tournament whose room two people are both in, on a profile: the trophy in the mark, the name, the sport, the
/// status and the start, opening the tournament's detail through `TournamentDestination` (the detail fetches it).
struct SharedTournamentRow: View {
    let tournament: TournamentSummary

    var body: some View {
        NavigationLink(value: tournament.destination) {
            GroupRowContent(name: tournament.name,
                            visibility: nil,
                            caption: tournament.caption,
                            hasUnread: false,
                            avatarSymbol: DesignTokens.Symbols.tournament)
        }
        .buttonStyle(.plain)
        .lilyHoverable()
        .accessibilityIdentifier(AccessibilityIdentifiers.tournamentRow(tournament.id))
    }
}
