import SwiftUI

struct EventCard: View {
    let event: SportEvent
    var distance: String?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                CardHeader(startsAt: event.startsAt) { badgeCapped in chips(badgeCapped: badgeCapped) }
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(event.title).font(LilyTheme.Fonts.cardTitle)
                    PlaceLine(name: event.locationName, distance: distance)
                }
                CapacityBar(event: event)
            }
        }
    }

    /// Chips stay whole; the group badge is the one that gives way (see `GroupBadge`).
    @ViewBuilder private func chips(badgeCapped: Bool) -> some View {
        EventTypeChip(type: event.type).fixedSize()
        if !event.isFree {
            Text(event.priceText).lilyChip(.regular).fixedSize()
        }
        if let group = event.group {
            GroupBadge(ref: group, capsWidth: badgeCapped)
        }
    }
}

#Preview {
    ContentScreen {
        EventCard(event: MockEventFixtures.make(now: .now, count: 1)[0]).padding()
    }
}
