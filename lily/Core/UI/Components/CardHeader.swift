import SwiftUI

/// Chips and the relative time in one row while they fit whole; otherwise the chips wrap over as many lines as
/// they need and the time goes under them, which a long group name and large Dynamic Type both call for. The event
/// and tournament cards draw their chip sets through it; `badgeCapped` tells the chips whether the group badge has to
/// give way (the one-row form) or may take its whole width (the wrapped form).
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
