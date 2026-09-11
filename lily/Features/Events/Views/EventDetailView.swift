import SwiftUI

/// Placeholder detail screen; joining arrives with the backend.
struct EventDetailView: View {
    let event: SportEvent

    var body: some View {
        ContentScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    SportChip(sport: event.sport)
                    ScreenTitle(text: event.title, subtitle: AppBranding.hostedByTitle(for: event.hostName))
                    GlassCard {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            Label(event.startsAt.formatted(date: .abbreviated, time: .shortened),
                                  systemImage: DesignTokens.Symbols.time)
                            Label(event.locationName, systemImage: DesignTokens.Symbols.location)
                            CapacityBar(event: event)
                        }
                    }
                    joinButton
                }
                .padding(DesignTokens.Spacing.xl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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
