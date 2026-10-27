import SwiftUI

/// The bar of pinned messages at the top of a chat, on glass, as Telegram draws it: an accent stripe cut into one
/// segment per pin (at most `pinStripeMaxSegments`, the shown one lit), "Pinned message" (with its place among several)
/// and the pinned message's quote; a tap jumps to the message, which the transcript then steps back from
/// (`PinnedBarPosition`); those who may pin get an unpin ✕ for the one shown.
struct PinnedBar: View {
    let pins: [PinnedMessage]
    let shownIndex: Int
    let canUnpin: Bool
    let onTap: () -> Void
    let onUnpin: () -> Void

    /// The stripe spans the bar's two lines, so it grows with the type.
    @ScaledMetric(relativeTo: .subheadline) private var stripeHeight = DesignTokens.Layout.pinStripeHeight
    private typealias Copy = AppBranding.Chat.Pins

    private var shown: PinnedMessage { pins[shownIndex] }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Button(action: onTap) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    stripe
                    VStack(alignment: .leading, spacing: 0) {
                        Text(pins.count > 1 ? Copy.pinnedMessage(shownIndex + 1, of: pins.count) : Copy.pinnedMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.lilyAccent)
                        Text(verbatim: shown.quote.displayText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Copy.showPinned)
            .accessibilityIdentifier(AccessibilityIdentifiers.pinnedBar)
            if canUnpin {
                Button(action: onUnpin) {
                    Image(systemName: DesignTokens.Symbols.dismiss)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Copy.unpin)
                .accessibilityIdentifier(AccessibilityIdentifiers.pinnedBarUnpin)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .glassEffect(.regular, in: .rect(cornerRadius: DesignTokens.Radius.md))
        .padding(.horizontal, DesignTokens.Layout.screenMargin)
        .padding(.bottom, DesignTokens.Spacing.xs)
    }

    /// One segment per pin, the newest at the bottom as the list runs; past `pinStripeMaxSegments` pins a window of
    /// them around the shown one.
    private var stripe: some View {
        let window = PinnedBarPosition.stripeWindow(shown: shownIndex,
                                                    count: pins.count,
                                                    maxSegments: DesignTokens.Layout.pinStripeMaxSegments)
        return VStack(spacing: DesignTokens.Layout.pinStripeSpacing) {
            ForEach(window, id: \.self) { index in
                Capsule()
                    .fill(Color.lilyAccent.opacity(index == shownIndex ? 1 : DesignTokens.Opacity.pinStripeIdle))
            }
        }
        .frame(width: DesignTokens.Layout.pinStripeWidth, height: stripeHeight)
        .accessibilityHidden(true)
    }
}
