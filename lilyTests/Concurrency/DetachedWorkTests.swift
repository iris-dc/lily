import Testing
@testable import lily

/// Work handed off the main actor through `DetachedWork` answers like a plain call, and a caller that is cancelled
/// takes the detached task down with it instead of leaving it to finish on its own.
struct DetachedWorkTests {
    @Test func theValueComesBackWhenNothingIsCancelled() async throws {
        let value = try await DetachedWork.run { 41 + 1 }

        #expect(value == 42)
    }

    @Test func anErrorOfTheWorkIsRethrown() async {
        await #expect(throws: AppError.attachmentTypeNotAllowed) {
            try await DetachedWork.run { () async throws -> Int in throw AppError.attachmentTypeNotAllowed }
        }
    }

    /// The caller is cancelled only once the work is running, so the early check cannot answer for it: a severed
    /// cancellation would let the work sleep its full ten seconds; a propagated one ends it at once.
    @Test func cancellingTheCallerCancelsTheDetachedWork() async {
        let (started, begun) = AsyncStream<Void>.makeStream()
        let clock = ContinuousClock()
        let caller = Task {
            try await DetachedWork.run {
                begun.yield()
                try await Task.sleep(for: .seconds(10))
                return 1
            }
        }
        for await _ in started { break }
        let start = clock.now

        caller.cancel()

        await #expect(throws: CancellationError.self) { try await caller.value }
        #expect(clock.now - start < .seconds(5), "the detached work was cancelled with its caller, not waited out")
    }
}
