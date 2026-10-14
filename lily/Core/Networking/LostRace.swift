import Foundation

/// `TRY_AGAIN` (`AppError.tryAgain`) means a write lost a race that is safe to rerun, so one repeat after a short
/// pause spares the user a second tap. A second `TRY_AGAIN` is treated like any other refusal.
///
/// The retry line ("<what> lost a race; retrying once") is logged here under the caller's category, so no caller
/// keeps a `logRetry` of its own; `WriteGate` wraps this for the screens whose write needs nothing else. The pause
/// runs through `sleep` so a test can hold it; production callers never pass one.
enum LostRace {
    static func attemptTwice<Value>(delay: Duration,
                                    sleep: Sleep = systemSleep,
                                    logger: any Logging,
                                    category: LogCategory,
                                    retrying what: String,
                                    _ attempt: () async throws -> Value) async throws -> Value {
        do {
            return try await attempt()
        } catch AppError.tryAgain {
            logger.info(category, "\(what) lost a race; retrying once")
            try await sleep(delay)
            return try await attempt()
        }
    }
}
