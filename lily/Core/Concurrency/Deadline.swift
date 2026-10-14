import Foundation

/// Runs work against a deadline: the first outcome wins, the loser is cancelled but not awaited. A task group would
/// wait for the loser, and a request that ignores cancellation (`RequestHold.wait()` in tests, a stalled socket) must
/// not hold a sign-out. Not for races whose loser must finish: `CoreLocationService` races in a structured group on
/// purpose, so its stream is closed before it answers.
enum Deadline {
    /// Thrown when the deadline wins and the caller named no error of its own.
    nonisolated struct Expired: Error {}

    static func within(_ timeout: Duration,
                       sleep: @escaping Sleep = systemSleep,
                       orThrow expired: any Error = Expired(),
                       _ work: @escaping () async throws -> Void) async throws {
        let worker = Task { try await work() }
        let first = FirstOutcome()
        let timer = Task {
            try? await sleep(timeout)
            first.settle(.failure(expired))
            worker.cancel()
        }
        Task {
            first.settle(await worker.result)
            timer.cancel()
        }
        try await first.outcome.get()
    }
}

/// The first of two results wins; the second is dropped.
private final class FirstOutcome {
    private var continuation: CheckedContinuation<Result<Void, any Error>, Never>?
    private var settled: Result<Void, any Error>?

    var outcome: Result<Void, any Error> {
        get async {
            if let settled { return settled }
            return await withCheckedContinuation { continuation = $0 }
        }
    }

    func settle(_ result: Result<Void, any Error>) {
        guard settled == nil else { return }
        settled = result
        continuation?.resume(returning: result)
        continuation = nil
    }
}
