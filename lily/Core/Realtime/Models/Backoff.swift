import Foundation

/// The wait before the next reconnect: walks `table` one entry per attempt and stays on its last, each wait jittered
/// by up to `jitter` either way.
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
