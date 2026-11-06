import SwiftUI

/// The how-full capsule itself: a faint track with the occupied share filled in the accent, amber when nearly full,
/// muted when full. `EntriesBar` draws it full width over its count; the map's event card draws a short one beside it.
struct CapacityMeter: View {
    let fillRatio: Double
    var isFull = false
    var isNearlyFull = false

    var body: some View {
        Capsule()
            .fill(Color.lilyInk.opacity(DesignTokens.Opacity.capacityTrack))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(fillStyle)
                        .frame(width: proxy.size.width * fillRatio)
                }
            }
            .frame(height: DesignTokens.Layout.capacityBarHeight)
            .accessibilityHidden(true)
    }

    private var fillStyle: AnyShapeStyle {
        if isFull { return AnyShapeStyle(.secondary) }
        if isNearlyFull { return AnyShapeStyle(Color.lilySecondary) }
        return AnyShapeStyle(Color.lilyAccent)
    }
}

extension CapacityMeter {
    init(event: SportEvent) {
        self.init(fillRatio: event.fillRatio, isFull: event.isFull, isNearlyFull: event.isNearlyFull)
    }
}
