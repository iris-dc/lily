import SwiftUI

/// Chips and the relative time on one row while they fit whole, else the chips wrapped over as many lines as they need
/// with the time underneath (a long group name, large Dynamic Type). `badgeCapped` tells the chips whether the group
/// badge must give way (the one-row form) or may take its whole width (the wrapped form).
struct CardHeader<Chips: View>: View {
    let startsAt: Date
    @ViewBuilder let chips: (_ badgeCapped: Bool) -> Chips

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                chips(true)
                Spacer()
                relativeTime.multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                FlowLayout(spacing: DesignTokens.Spacing.sm, rowSpacing: DesignTokens.Spacing.sm) { chips(false) }
                relativeTime
            }
        }
    }

    private var relativeTime: some View {
        Text(startsAt, format: .relative(presentation: .named))
            .font(LilyTheme.Fonts.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    ContentScreen {
        GlassCard {
            CardHeader(startsAt: .now.addingTimeInterval(3_600)) { _ in
                EventTypeChip(type: .football).fixedSize()
            }
        }
        .padding()
    }
}
