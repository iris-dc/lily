import SwiftUI

/// Thin bar filled with an occupied share: accent normally, amber when nearly full, muted when full, with the count
/// under it. The track is faint so that an empty one reads as empty; without a share to fill (a game with no limit) the
/// count stands alone. An event's capacity and a tournament's entries both draw through it.
struct EntriesBar: View {
    let fillRatio: Double
    let text: String
    var isFull = false
    var isNearlyFull = false
    var showsTrack = true

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            if showsTrack {
                CapacityMeter(fillRatio: fillRatio, isFull: isFull, isNearlyFull: isNearlyFull)
            }
            Text(text)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

extension EntriesBar {
    /// An event's share of its capacity; a game without a limit shows its count alone.
    init(event: SportEvent) {
        self.init(fillRatio: event.fillRatio,
                  text: event.capacityText,
                  isFull: event.isFull,
                  isNearlyFull: event.isNearlyFull,
                  showsTrack: event.playerLimit.hasCapacity)
    }

    /// A tournament's entries of its maximum, amber once three quarters are in.
    init(tournament: Tournament) {
        self.init(fillRatio: tournament.fillRatio,
                  text: tournament.entriesText,
                  isFull: tournament.isFull,
                  isNearlyFull: tournament.isNearlyFull)
    }
}
