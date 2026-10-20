import Foundation
import Testing
@testable import lily

struct TranscriptArrivalsTests {
    private static let start = Date(timeIntervalSince1970: 1_800_000_000)
    private let lasting: TimeInterval = 1

    private func log(from ids: [String]) -> TranscriptArrivals {
        var log = TranscriptArrivals()
        log.update(to: ids, at: Self.start, history: .idle, lasting: lasting)
        return log
    }

    /// The rows the transcript first draws (a cached room, the first page) appear as they are.
    @Test func theFirstRowsDoNotArrive() {
        let log = log(from: ["day", "m1", "m2"])
        #expect(log.starts.isEmpty)
    }

    @Test func anAppendedRowArrivesWhenItIsFirstDrawn() {
        var log = log(from: ["day", "m1"])
        let now = Self.start.addingTimeInterval(5)
        log.update(to: ["day", "m1", "c-1"], at: now, history: .idle, lasting: lasting)
        #expect(log.starts == ["c-1": now])
        #expect(log.start(of: "m1") == nil)
    }

    /// The unsent bubble turning into the stored message keeps its row id, so its arrival runs on from the send.
    @Test func aRowChangedInPlaceKeepsItsArrival() {
        var log = log(from: ["day", "m1"])
        let sent = Self.start.addingTimeInterval(5)
        log.update(to: ["day", "m1", "c-1"], at: sent, history: .idle, lasting: lasting)
        log.update(to: ["day", "m1", "c-1"], at: sent.addingTimeInterval(0.1), history: .idle, lasting: lasting)
        #expect(log.start(of: "c-1") == sent)
    }

    @Test func anOlderPagePrependedAboveDoesNotArrive() {
        var log = log(from: ["day", "m3"])
        log.update(to: ["day-0", "m1", "m2", "day", "m3"], at: Self.start, history: .idle, lasting: lasting)
        #expect(log.starts.isEmpty)
    }

    /// A day chip before a new day's first message arrives with it.
    @Test func everyRowAfterTheLastOneHeldArrives() {
        var log = log(from: ["day", "m1"])
        log.update(to: ["day", "m1", "day-2", "m2"], at: Self.start, history: .idle, lasting: lasting)
        #expect(Set(log.starts.keys) == ["day-2", "m2"])
    }

    @Test func aRemovalArrivesNothing() {
        var log = log(from: ["day", "m1", "c-1"])
        log.update(to: ["day", "m1"], at: Self.start, history: .idle, lasting: lasting)
        #expect(log.starts.isEmpty)
    }

    /// The history loading on open or on Try again brings what was missed, which appears as it is.
    @Test func nothingArrivesWhileTheHistoryLoads() {
        var log = log(from: ["day", "m1"])
        let loading = TranscriptArrivals.HistoryLoads(isInFlight: true, finished: 0)
        log.update(to: ["day", "m1", "m2"], at: Self.start, history: loading, lasting: lasting)
        #expect(log.starts.isEmpty)
        let done = TranscriptArrivals.HistoryLoads(isInFlight: false, finished: 1)
        log.update(to: ["day", "m1", "m2"], at: Self.start, history: done, lasting: lasting)
        log.update(to: ["day", "m1", "m2", "m3"], at: Self.start, history: done, lasting: lasting)
        #expect(Set(log.starts.keys) == ["m3"], "the held-back row became a row already held")
    }

    /// A load whose last page lands in the same turn that clears its flag is seen already idle, with one more finished.
    @Test func rowsALoadBroughtAsItEndedDoNotArrive() {
        var log = log(from: [])
        let done = TranscriptArrivals.HistoryLoads(isInFlight: false, finished: 1)
        log.update(to: ["day", "m1", "m2"], at: Self.start, history: done, lasting: lasting)
        #expect(log.starts.isEmpty)
        log.update(to: ["day", "m1", "m2", "c-1"], at: Self.start, history: done, lasting: lasting)
        #expect(Set(log.starts.keys) == ["c-1"], "the next append arrives again")
    }

    /// A room the caller cleared draws nothing; the first message after it arrives with its day chip.
    @Test func rowsAfterAnEmptyTranscriptArrive() {
        var log = log(from: [])
        log.update(to: ["day", "c-1"], at: Self.start, history: .idle, lasting: lasting)
        #expect(Set(log.starts.keys) == ["day", "c-1"])
    }

    @Test func anArrivalIsForgottenOnceItIsOver() {
        var log = log(from: ["day"])
        log.update(to: ["day", "m1"], at: Self.start, history: .idle, lasting: lasting)
        log.update(to: ["day", "m1", "m2"], at: Self.start.addingTimeInterval(2), history: .idle, lasting: lasting)
        #expect(log.start(of: "m1") == nil)
        #expect(log.start(of: "m2") == Self.start.addingTimeInterval(2))
    }
}
