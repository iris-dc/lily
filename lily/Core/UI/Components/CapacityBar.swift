import SwiftUI

/// Thin bar showing how full an event is: red normally, amber when nearly full, muted when full.
struct CapacityBar: View {
    let event: SportEvent

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Capsule()
                .fill(.quaternary)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(fillStyle)
                            .frame(width: proxy.size.width * event.fillRatio)
                    }
                }
                .frame(height: DesignTokens.Layout.capacityBarHeight)
            Text(event.isFull ? "Full" : "\(event.spotsLeft) of \(event.capacity) spots left")
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var fillStyle: AnyShapeStyle {
        if event.isFull { return AnyShapeStyle(.secondary) }
        if event.isNearlyFull { return AnyShapeStyle(Color.lilySecondary) }
        return AnyShapeStyle(Color.lilyAccent)
    }
}
