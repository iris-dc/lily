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
                    .scaleEffect(revealed ? 1 : DesignTokens.Layout.previewCardEntranceScale)
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
