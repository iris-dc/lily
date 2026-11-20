import Foundation
import Testing
import UIKit
@testable import lily

@MainActor
struct BadgePaneDiagnosticsTests {
    private final class SinkCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0

        func bump() {
            lock.lock()
            count += 1
            lock.unlock()
        }

        var calls: Int {
            lock.lock()
            defer { lock.unlock() }
            return count
        }
    }

    private func makeDiagnostics(clock: FakeFrameClock,
                                 now: @escaping () -> CFTimeInterval,
                                 flushDelay: TimeInterval = 60,
                                 onWrite: @escaping @Sendable () -> Void = {}) -> BadgePaneDiagnostics {
        BadgePaneDiagnostics(clock: clock, now: now, flushDelay: flushDelay, writeSink: { _, _ in onWrite() })
    }

    @Test func theRingKeepsOnlyTheNewestLines() {
        var time = 0.0
        let diagnostics = makeDiagnostics(clock: FakeFrameClock(), now: { time })
        let bar = UITabBar()
        diagnostics.note("oldest", bar: bar, capsule: UIView())
        for index in 0..<4200 {
            time += 0.01
            diagnostics.note("evt\(index)", bar: bar, capsule: UIView())
        }
        #expect(diagnostics.lines.count == 4000, "the ring is bounded")
        #expect(diagnostics.lines.last?.contains("evt4199") == true, "the newest line survives")
        #expect(diagnostics.lines.contains { $0.contains("oldest") } == false, "the oldest fell off the ring")
    }

    @Test func aRepeatedEventExtendsTheSamplingTail() {
        var time = 0.0
        let clock = FakeFrameClock()
        let diagnostics = makeDiagnostics(clock: clock, now: { time })
        let bar = UITabBar()
        diagnostics.note("one", bar: bar, capsule: UIView())
        #expect(clock.isRunning, "an event starts the tail")
        time = 1.5
        clock.tick(at: time)
        diagnostics.note("two", bar: bar, capsule: UIView())
        time = 2.5
        clock.tick(at: time)
        #expect(clock.isRunning, "a repeated event extends the tail past the first deadline")
        time = 3.6
        clock.tick(at: time)
        #expect(!clock.isRunning, "the tail ends after the extended deadline")
        #expect(!diagnostics.isSampling)
    }

    @Test func rapidAppendsCoalesceIntoOneWrite() async throws {
        let counter = SinkCounter()
        let diagnostics = makeDiagnostics(clock: FakeFrameClock(),
                                          now: { 0 },
                                          flushDelay: 0.05,
                                          onWrite: { counter.bump() })
        let bar = UITabBar()
        for _ in 0..<10 {
            diagnostics.note("burst", bar: bar, capsule: UIView())
        }
        try await Task.sleep(for: .milliseconds(400))
        #expect(counter.calls == 1, "appends inside the delay coalesce into one buffered write")
    }
}
