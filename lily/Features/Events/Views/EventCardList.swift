import SwiftUI

/// The card list alone: one `NavigationLink` per event. It knows nothing about scrolling, refreshing or empty states,
/// so a screen that already scrolls (a group's detail) can embed it as it is. The list sits at the screen margin
/// unless the container pads its content itself, in which case it passes `horizontalPadding: 0`. One column on a
/// compact width, as many as fit on a regular one (`AdaptiveCardGrid`).
struct EventCardList: View {
    let events: [SportEvent]
    let distance: (SportEvent) -> String?
    var horizontalPadding: CGFloat = DesignTokens.Layout.screenMargin
    /// Inside a readable column (a group's detail) the list keeps one column on every width.
    var singleColumn = false

    var body: some View {
        AdaptiveCardGrid(data: events, singleColumn: singleColumn) { event in
            NavigationLink(value: event) {
                EventCard(event: event, distance: distance(event))
            }
            .buttonStyle(.plain)
            .lilyHoverable()
        }
        .padding(.horizontal, horizontalPadding)
    }
}
