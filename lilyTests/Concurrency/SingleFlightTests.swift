import Testing
@testable import lily

@MainActor
struct SingleFlightTests {
    private let flight = SingleFlight()
    private let gate = RequestHold()
    private let log = RunLog()

    /// A second caller while the first run is held: one run, and both callers return once it ends.
    @Test func callersMadeWhileRunningJoinTheRunInFlight() async {
        gate.isEnabled = true

        let first = Task { await flight.run { await held() } }
        await settle(until: { flight.isRunning })
        let second = Task { await flight.run { await held() } }
        await Task.yield()
        gate.release()
        await first.value
        await second.value

        #expect(log.runs == 1 && !flight.isRunning)
    }

    @Test func runsAgainOnceTheRunInFlightEnded() async {
        await flight.run { await held() }
        await flight.run { await held() }

        #expect(log.runs == 2 && !flight.isRunning)
    }

    /// The work is the flight's own task: a caller cancelled while waiting for it does not cancel it.
    @Test func aCancelledCallerDoesNotCancelTheWork() async {
        gate.isEnabled = true

        let caller = Task { await flight.run { await held() } }
        await settle(until: { flight.isRunning })
        caller.cancel()
        gate.release()
        await caller.value

        #expect(log.runs == 1 && log.uncancelledRuns == 1 && !flight.isRunning)
    }

    private func held() async {
        log.runs += 1
        await gate.wait()
        if !Task.isCancelled { log.uncancelledRuns += 1 }
    }
}

@MainActor
private final class RunLog {
    var runs = 0
    var uncancelledRuns = 0
}
