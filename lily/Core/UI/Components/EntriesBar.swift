import SwiftUI

/// Thin bar filled with an occupied share: accent normally, amber when nearly full, muted when full, with the count
/// under it. The track is faint so that an empty one reads as empty; without a share to fill (a game with no limit) the
/// count stands alone. The event's `CapacityBar` and a tournament's entries both draw through it.
struct EntriesBar: View {
    let fillRatio: Double
    let text: String
    var isFull = false
    var isNearlyFull = false
    var showsTrack = true

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            if showsTrack {
                track
            }
            Text(text)
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
                        .frame(width: proxy.size.width * fillRatio)
                }
            }
            .frame(height: DesignTokens.Layout.entriesBarHeight)
    }

    private var fillStyle: AnyShapeStyle {
        if isFull { return AnyShapeStyle(.secondary) }
        if isNearlyFull { return AnyShapeStyle(Color.lilySecondary) }
        return AnyShapeStyle(Color.lilyAccent)
    }
}

extension EntriesBar {
    /// A tournament's entries of its maximum, amber once three quarters are in.
    init(tournament: Tournament) {
        self.init(fillRatio: tournament.fillRatio,
                  text: tournament.entriesText,
                  isFull: tournament.isFull,
                  isNearlyFull: !tournament.isFull && tournament.fillRatio >= AppConfig.Events.nearlyFullRatio)
    }
}
