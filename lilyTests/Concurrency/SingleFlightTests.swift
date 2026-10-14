import Testing
@testable import lily

@MainActor
struct SingleFlightTests {
    private let flight = SingleFlight()
    private let gate = RequestHold()
    private let log = RunLog()

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

    /// The work runs in the flight's own task, so a caller's cancellation never reaches it.
    @Test func aCancelledCallerDoesNotCancelTheWork() async {
        gate.isEnabled = true

        let caller = Task { await flight.run { await held() } }
        await settle(until: { flight.isRunning })
        caller.cancel()
        gate.release()
        await caller.value

        #expect(log.runs == 1 && log.uncancelledRuns == 1 && !flight.isRunning)
    }

    @Test func aCallerForAnotherKeyWaitsOutTheRunAndThenRunsItself() async {
        gate.isEnabled = true

        let first = Task { await flight.run(key: "a") { await held(as: "a") } }
        await settle(until: { flight.isRunning })
        let second = Task { await flight.run(key: "b") { await held(as: "b") } }
        await Task.yield()
        #expect(log.events == ["a"], "b waits, it does not run beside a")
        gate.release()
        await first.value
        await second.value

        #expect(log.events == ["a", "a done", "b", "b done"] && !flight.isRunning)
    }

    @Test func callersForTheSameKeyJoinTheRunInFlight() async {
        gate.isEnabled = true

        let first = Task { await flight.run(key: "a") { await held(as: "a") } }
        await settle(until: { flight.isRunning })
        let second = Task { await flight.run(key: "a") { await held(as: "a") } }
        await Task.yield()
        gate.release()
        await first.value
        await second.value

        #expect(log.runs == 1 && !flight.isRunning)
    }

    @Test func anUnkeyedCallerJoinsWhateverRuns() async {
        gate.isEnabled = true

        let keyed = Task { await flight.run(key: "a") { await held(as: "a") } }
        await settle(until: { flight.isRunning })
        let unkeyed = Task { await flight.run { await held(as: "any") } }
        await Task.yield()
        gate.release()
        await keyed.value
        await unkeyed.value

        #expect(log.events == ["a", "a done"] && log.runs == 1)
    }

    private func held() async {
        log.runs += 1
        await gate.wait()
        if !Task.isCancelled { log.uncancelledRuns += 1 }
    }

    private func held(as key: String) async {
        log.events.append(key)
        log.runs += 1
        await gate.wait()
        log.events.append("\(key) done")
    }
}

@MainActor
private final class RunLog {
    var runs = 0
    var uncancelledRuns = 0
    var events: [String] = []
}
