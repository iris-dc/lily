import SwiftUI

/// An event's share of its capacity, drawn through `EntriesBar`: red normally, amber when nearly full, muted when full.
/// A game without a limit has no share to fill and shows its count alone.
struct CapacityBar: View {
    let event: SportEvent

    var body: some View {
        EntriesBar(fillRatio: event.fillRatio,
                   text: event.capacityText,
                   isFull: event.isFull,
                   isNearlyFull: event.isNearlyFull,
                   showsTrack: event.playerLimit.hasCapacity)
    }
}
