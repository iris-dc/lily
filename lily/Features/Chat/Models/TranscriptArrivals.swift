import Foundation

/// Which rows of a transcript are arriving, and since when. Every row after the last one the transcript already held
/// arrives; an older page prepended above, a row changed in place (the unsent bubble turning into the stored message
/// keeps its id) and a removal never do. The first rows the transcript sees, and those a history load brings, appear as
/// they are. Pure, so the rules are tested without a view.
nonisolated struct TranscriptArrivals: Equatable, Sendable {
    /// The room's history loads as the transcript sees them: whether one is in flight, and how many have finished.
    struct HistoryLoads: Equatable, Sendable {
        var isInFlight: Bool
        var finished: Int

        static let idle = HistoryLoads(isInFlight: false, finished: 0)
    }

    private(set) var starts: [String: Date] = [:]
    /// The rows as the transcript drew them last; `nil` before the first update.
    private var heldIDs: [String]?
    /// The finished loads at the last update.
    private var seenLoads = 0

    func start(of id: String) -> Date? {
        starts[id]
    }

    /// Brings the log up to `ids`, the rows as the transcript now draws them, at `now`. Arrivals older than `lasting`
    /// are over and forgotten.
    mutating func update(to ids: [String], at now: Date, history: HistoryLoads, lasting: TimeInterval) {
        // A load that ends without suspending after its last page writes those rows and clears its flag in one turn, so
        // the update that sees them may already see it idle; the finished count still tells.
        let isQuiet = !history.isInFlight && history.finished == seenLoads
        seenLoads = history.finished
        guard ids != heldIDs else { return }
        defer { heldIDs = ids }
        starts = starts.filter { now.timeIntervalSince($0.value) < lasting }
        guard let heldIDs, isQuiet else { return }
        let held = Set(heldIDs)
        let firstNew = ids.lastIndex(where: held.contains).map { $0 + 1 } ?? ids.startIndex
        for id in ids[firstNew...] {
            starts[id] = now
        }
    }
}
