import SwiftUI

/// The card list alone: one `NavigationLink` per event. It knows nothing about scrolling, refreshing or empty states,
/// so a screen that already scrolls (a group's detail) can embed it as it is. The list sits at the screen margin
/// unless the container pads its content itself, in which case it passes `horizontalPadding: 0`.
struct EventCardList: View {
    let events: [SportEvent]
    let distance: (SportEvent) -> String?
    var horizontalPadding: CGFloat = DesignTokens.Layout.screenMargin

    var body: some View {
        LazyVStack(spacing: DesignTokens.Spacing.md) {
            ForEach(events) { event in
                NavigationLink(value: event) {
                    EventCard(event: event, distance: distance(event))
                }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, horizontalPadding)
    }
}
