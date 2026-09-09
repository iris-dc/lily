import SwiftUI

struct EventCard: View {
    let event: SportEvent
    var distance: String?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack {
                    SportChip(sport: event.sport)
                    Spacer()
                    Text(event.startsAt, format: .relative(presentation: .named))
                        .font(LilyTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(event.title).font(LilyTheme.Fonts.cardTitle)
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Label(event.locationName, systemImage: DesignTokens.Symbols.location)
                        if let distance {
                            Text("·")
                            Label(distance, systemImage: DesignTokens.Symbols.distance)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                CapacityBar(event: event)
            }
        }
    }
}

#Preview {
    ZStack {
        AuroraBackground(intensity: DesignTokens.Aurora.contentIntensity)
        EventCard(event: MockEventFixtures.make(now: .now, count: 1)[0]).padding()
    }
}
