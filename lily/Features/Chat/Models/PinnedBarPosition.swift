import Foundation

/// Where the pinned bar stands among a chat's pins (oldest first, as the backend lists them): the newest shows unless
/// a tap stepped back, a step goes to the pin before and round to the newest after the oldest, and the stripe shows a
/// window of segments around the shown pin when there are more than it has room for.
nonisolated enum PinnedBarPosition {
    /// The pin shown for `index` (counted from the oldest; `nil` or past the end shows the newest) among `count` pins.
    static func shown(_ index: Int?, count: Int) -> Int {
        max(0, min(index ?? count - 1, count - 1))
    }

    /// The pin a tap on the bar steps back to.
    static func steppedBack(from shown: Int, count: Int) -> Int {
        shown == 0 ? count - 1 : shown - 1
    }

    /// The pins the stripe draws, at most `maxSegments`, the newest at the end and the shown one inside.
    static func stripeWindow(shown: Int, count: Int, maxSegments: Int) -> Range<Int> {
        let segments = min(count, maxSegments)
        let first = min(max(0, shown - segments + 1), count - segments)
        return first..<first + segments
    }
}
