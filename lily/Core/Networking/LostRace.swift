import Foundation

/// `TRY_AGAIN` (`AppError.tryAgain`) means a write lost a race that is safe to rerun, so one repeat after a short
/// pause spares the user a second tap. A second `TRY_AGAIN` is treated like any other refusal.
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
