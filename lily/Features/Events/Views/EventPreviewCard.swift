import SwiftUI

/// Compact one-row summary of an event, used in the landing deck and as the map's selected-pin card. At accessibility
/// type sizes the row becomes a column, so the title and caption get the full width instead of one truncated line.
struct EventPreviewCard: View {
    let event: SportEvent
    /// Optional trailing detail such as distance.
    var detail: String?
    @Environment(\.dynamicTypeSize) private var typeSize

    private var isRow: Bool { !typeSize.isAccessibilitySize }

    var body: some View {
        let layout = isRow
            ? AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.md))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
        layout {
            Image(systemName: event.type.symbolName)
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.lilySecondary)
                .frame(width: DesignTokens.Layout.controlHeight, height: DesignTokens.Layout.controlHeight)
                .glassEffect(.regular.tint(Color.lilySecondary.opacity(DesignTokens.Opacity.glassTint)), in: .circle)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(isRow ? 1 : DesignTokens.Layout.accessibilityPreviewLines)
                Text(caption)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(isRow ? 1 : DesignTokens.Layout.accessibilityPreviewLines)
                // The group gets a line of its own: in the caption it would truncate the spots, in the trailing
                // slot it squeezed the title on the landing deck.
                if let group = event.group {
                    Label(group.name, systemImage: DesignTokens.Symbols.groups)
                        .font(LilyTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(isRow ? 1 : DesignTokens.Layout.accessibilityPreviewLines)
                        .truncationMode(.tail)
                }
            }
            if isRow {
                Spacer(minLength: 0)
            }
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
        let relativeStart = event.startsAt.formatted(.relative(presentation: .named).locale(AppLocale.locale))
        var parts = [relativeStart, event.availabilityText]
        if !event.isFree { parts.append(event.priceText) }
        return parts.joined(separator: AppBranding.Events.captionSeparator)
    }
}
