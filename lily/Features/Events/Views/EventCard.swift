import SwiftUI

struct EventCard: View {
    let event: SportEvent
    var distance: String?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                header
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(event.title).font(LilyTheme.Fonts.cardTitle)
                    PlaceLine(name: event.locationName, distance: distance)
                }
                CapacityBar(event: event)
            }
        }
    }

    /// Chips and the relative time in one row while they fit whole; otherwise the chips wrap over as many lines as
    /// they need and the time goes under them, which a long group name and large Dynamic Type both call for.
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

    private var relativeTime: some View {
        Text(event.startsAt, format: .relative(presentation: .named))
            .font(LilyTheme.Fonts.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    ContentScreen {
        EventCard(event: MockEventFixtures.make(now: .now, count: 1)[0]).padding()
    }
}
