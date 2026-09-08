import SwiftUI

/// Real upcoming events laid out as a loosely stacked deck, so the landing shows the product instead of describing it.
struct EventPreviewDeck: View {
    let events: [SportEvent]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                EventPreviewCard(event: event)
                    .frame(width: DesignTokens.Layout.previewCardWidth)
                    .rotationEffect(.degrees(tilt(for: index)))
                    .offset(x: shift(for: index))
                    .opacity(revealed ? 1 : 0)
                    .scaleEffect(revealed ? 1 : 0.94)
                    .animation(entrance(delayIndex: index), value: revealed)
            }
        }
        .onChange(of: events.count, initial: true) { _, count in
            if count > 0 { revealed = true }
        }
        .accessibilityHidden(true)
    }

    /// Alternate the lean and the side so the stack reads as casually dropped cards.
    private func tilt(for index: Int) -> Double {
        index.isMultiple(of: 2) ? -DesignTokens.Layout.previewCardTilt : DesignTokens.Layout.previewCardTilt
    }

    private func shift(for index: Int) -> CGFloat {
        index.isMultiple(of: 2) ? -DesignTokens.Layout.previewCardShift : DesignTokens.Layout.previewCardShift
    }

    private func entrance(delayIndex: Int) -> Animation? {
        guard !reduceMotion else { return nil }
        return .spring(duration: DesignTokens.Duration.slow)
            .delay(Double(delayIndex) * DesignTokens.Duration.previewCardStagger)
    }
}

/// Compact one-row summary of an event, used in the landing deck and as the map's selected-pin card.
struct EventPreviewCard: View {
    let event: SportEvent
    /// Optional trailing detail such as distance.
    var detail: String?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: event.sport.symbolName)
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.lilySecondary)
                .frame(width: DesignTokens.Layout.controlHeight, height: DesignTokens.Layout.controlHeight)
                .glassEffect(.regular.tint(Color.lilySecondary.opacity(DesignTokens.Opacity.glassTint)), in: .circle)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(event.startsAt, format: .relative(presentation: .named)) · \(event.spotsLeft) spots left")
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let detail {
                Text(detail)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(Color.lilyAccent)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .glassEffect(.regular, in: .rect(cornerRadius: DesignTokens.Radius.md))
    }
}
