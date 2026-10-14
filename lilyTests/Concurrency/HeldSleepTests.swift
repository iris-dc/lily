import Foundation
import Testing
@testable import lily

/// `HeldSleep` is the sleep every timer-driven suite steers; these pin the wake-up rules those suites rely on.
@MainActor
struct HeldSleepTests {
    private let sleep = HeldSleep()

    private func sleeper(for duration: Duration) -> Task<Void, any Error> {
        Task { try await sleep.sleep(for: duration) }
    }

    /// Two sleepers may park in either order, so the held durations are compared sorted.
    private func settleUntilBothHeld() async {
        await settle(until: { sleep.held.sorted() == [.seconds(1), .seconds(2)] })
    }

    @Test func aCancelledSleeperWakesAloneAndThrows() async throws {
        let first = sleeper(for: .seconds(1))
        let second = sleeper(for: .seconds(2))
        await settleUntilBothHeld()

        first.cancel()
        await settle(until: { sleep.held == [.seconds(2)] })

        await #expect(throws: CancellationError.self) { try await first.value }
        #expect(sleep.held == [.seconds(2)], "the other sleeper keeps waiting")
        sleep.release()
        try await second.value
    }

    @Test func releaseWhereWakesOnlyTheMatchingSleeper() async throws {
        let first = sleeper(for: .seconds(1))
        let second = sleeper(for: .seconds(2))
        await settleUntilBothHeld()

        sleep.release { $0 == .seconds(2) }

        try await second.value
        #expect(sleep.held == [.seconds(1)])
        sleep.release()
        try await first.value
    }

    @Test func releaseWakesEverySleeper() async throws {
        let first = sleeper(for: .seconds(1))
        let second = sleeper(for: .seconds(2))
        await settleUntilBothHeld()

        sleep.release()

        try await first.value
        try await second.value
        #expect(sleep.held.isEmpty)
    }

    @Test func aSleepRequestedByACancelledTaskThrowsAndIsNeverLeftHeld() async {
        let task = sleeper(for: .seconds(1))
        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
        await settle(until: { sleep.held.isEmpty })
        #expect(sleep.requested == [.seconds(1)], "the request is recorded even though it never slept")
    }
}

/// The hold behind every `HoldsRequests` fake: its two waits differ only in what a cancelled caller learns.
@MainActor
struct RequestHoldTests {
    private let hold = RequestHold()

    private func yieldRepeatedly() async {
        for _ in 0..<10 { await Task.yield() }
    }

    @Test func aCallerCancelledWhileHeldStaysParkedUntilReleased() async {
        hold.isEnabled = true
        let task = Task { await hold.wait(); return "through" }
        await settle(until: { hold.isHolding })

        task.cancel()
        await yieldRepeatedly()
        #expect(hold.isHolding, "a cancelled caller is parked like any other until the hold lifts")

        hold.release()
        let answer = await task.value
        #expect(answer == "through")
        #expect(!hold.isHolding && !hold.isEnabled)
    }

    @Test func waitOrThrowReportsTheCancellationOnceReleased() async {
        hold.isEnabled = true
        let task = Task { try await hold.waitOrThrow() }
        await settle(until: { hold.isHolding })

        task.cancel()
        await yieldRepeatedly()
        #expect(hold.isHolding, "the cancellation surfaces only when the hold lifts, like a URLSession task's")

        hold.release()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(!hold.isHolding && !hold.isEnabled)
    }

    @Test func waitReturnsAtOnceWhileDisabled() async {
        #expect(!hold.isEnabled)

        await hold.wait()

        #expect(!hold.isHolding)
    }
}
