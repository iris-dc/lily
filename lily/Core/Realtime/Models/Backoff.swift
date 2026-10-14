import Foundation

/// Where along the reconnect table the next wait falls: `next` answers the table's entry at `attempt` (its last one
/// past the end) times `1 + random(-jitter...jitter)` and moves on; `reset` starts the table over.
nonisolated struct Backoff: Equatable, Sendable {
    let table: [TimeInterval]
    let jitter: Double
    private(set) var attempt = 0

    init(table: [TimeInterval] = AppConfig.Realtime.reconnectBackoffSeconds,
         jitter: Double = AppConfig.Realtime.reconnectJitter) {
        precondition(!table.isEmpty, "a backoff needs at least one wait")
        self.table = table
        self.jitter = jitter
    }

    mutating func next(random: (ClosedRange<Double>) -> Double) -> TimeInterval {
        let base = table[min(attempt, table.count - 1)]
        attempt += 1
        return base * (1 + random(-jitter...jitter))
    }

    mutating func reset() {
        attempt = 0
    }
}
