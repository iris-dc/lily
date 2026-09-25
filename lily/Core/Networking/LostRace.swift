import Foundation

/// `TRY_AGAIN` (`AppError.tryAgain`) means a write lost a race that is safe to rerun, so one repeat after a short
/// pause spares the user a second tap. A second `TRY_AGAIN` is treated like any other refusal.
enum LostRace {
    static func attemptTwice<Value>(delay: Duration,
                                    onRetry: () -> Void,
                                    _ attempt: () async throws -> Value) async throws -> Value {
        do {
            return try await attempt()
        } catch AppError.tryAgain {
            onRetry()
            try await Task.sleep(for: delay)
            return try await attempt()
        }
    }
}
