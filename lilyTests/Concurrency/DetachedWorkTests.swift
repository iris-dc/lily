import Testing
@testable import lily

/// `DetachedWork` answers like a plain call, and a cancelled caller takes the detached task down with it.
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

    /// Cancelled only once the work is running, or `Task.sleep`'s early check would answer for the propagation.
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
