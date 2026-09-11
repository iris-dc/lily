import SwiftUI

/// Placeholder detail screen; joining arrives with the backend.
struct EventDetailView: View {
    let event: SportEvent

    var body: some View {
        ContentScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    EventTypeChip(type: event.type)
                    ScreenTitle(text: event.title, subtitle: AppBranding.hostedByTitle(for: event.hostName))
                    if let description = event.description {
                        Text(description).font(.body)
                    }
                    facts
                    if let lookingFor = event.lookingFor {
                        lookingForCard(lookingFor)
                    }
                    joinButton
                }
                .padding(DesignTokens.Spacing.xl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Time, place, price and level, then how full it is. Price only when the game costs something, level only when set.
    private var facts: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Label(event.startsAt.formatted(date: .abbreviated, time: .shortened), systemImage: DesignTokens.Symbols.time)
                Label(event.locationName, systemImage: DesignTokens.Symbols.location)
                if !event.isFree {
                    Label(AppBranding.Events.perPerson(event.priceText), systemImage: DesignTokens.Symbols.price)
                }
                if let level = event.skillLevel {
                    Label(AppBranding.Events.level(level.displayName), systemImage: DesignTokens.Symbols.level)
                }
                CapacityBar(event: event)
            }
            .labelStyle(.iconColumn)
        }
    }

    private func lookingForCard(_ text: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Label(AppBranding.Events.lookingForTitle, systemImage: DesignTokens.Symbols.lookingFor)
                    .labelStyle(.iconColumn)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                Text(text).font(.body)
            }
        }
    }

    private var joinButton: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Button(event.isFull ? AppBranding.eventFullAction : AppBranding.joinAction) {}
                .lilyProminentButton()
                .disabled(true)
            Text(AppBranding.joinComingSoon)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        EventDetailView(event: MockEventFixtures.make(now: .now, count: 1)[0])
    }
}
