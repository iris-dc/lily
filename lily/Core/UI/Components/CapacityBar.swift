import SwiftUI

/// Thin bar filled with the occupied share of an event: red normally, amber when nearly full, muted when full.
/// The track is faint so that an empty event reads as empty. A game without a limit has no share to fill and shows
/// its count alone.
struct CapacityBar: View {
    let event: SportEvent

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            if event.playerLimit.hasCapacity {
                track
            }
            Text(event.capacityText)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var track: some View {
        Capsule()
            .fill(Color.lilyInk.opacity(DesignTokens.Opacity.capacityTrack))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(fillStyle)
                        .frame(width: proxy.size.width * event.fillRatio)
                }
            }
            .frame(height: DesignTokens.Layout.capacityBarHeight)
    }

    private var fillStyle: AnyShapeStyle {
        if event.isFull { return AnyShapeStyle(.secondary) }
        if event.isNearlyFull { return AnyShapeStyle(Color.lilySecondary) }
        return AnyShapeStyle(Color.lilyAccent)
    }
}
