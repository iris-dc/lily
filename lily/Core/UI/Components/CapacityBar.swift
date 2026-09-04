import SwiftUI

/// Thin red bar showing how full an event is, with a spots-left label.
struct CapacityBar: View {
    let event: SportEvent

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Capsule()
                .fill(.quaternary)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(event.isFull ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.lilyAccent))
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
}
