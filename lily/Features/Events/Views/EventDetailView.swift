import SwiftUI

/// Placeholder detail screen; joining arrives with the backend.
struct EventDetailView: View {
    let event: SportEvent

    var body: some View {
        ZStack {
            AuroraBackground(intensity: DesignTokens.Opacity.faint)
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    SportChip(sport: event.sport)
                    ScreenTitle(text: event.title, subtitle: "Hosted by \(event.hostName)")
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
            Button {
            } label: {
                Text(event.isFull ? "Event is full" : "Join")
                    .fullWidthButtonLabel()
            }
            .lilyProminentButton()
            .disabled(true)
            Text("Joining arrives with the backend.")
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
        }
    }
}
