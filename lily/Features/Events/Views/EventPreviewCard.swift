import SwiftUI

/// Compact one-row summary of an event, used in the landing deck and as the map's selected-pin card.
struct EventPreviewCard: View {
    let event: SportEvent
    /// Optional trailing detail such as distance.
    var detail: String?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: event.type.symbolName)
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.lilySecondary)
                .frame(width: DesignTokens.Layout.controlHeight, height: DesignTokens.Layout.controlHeight)
                .glassEffect(.regular.tint(Color.lilySecondary.opacity(DesignTokens.Opacity.glassTint)), in: .circle)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(caption)
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

    /// "in 3 hours · 4 spots left", plus the price when the game costs something.
    private var caption: String {
        var parts = [event.startsAt.formatted(.relative(presentation: .named)), event.availabilityText]
        if !event.isFree { parts.append(event.priceText) }
        return parts.joined(separator: AppBranding.Events.captionSeparator)
    }
}
