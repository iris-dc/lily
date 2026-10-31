import Foundation
import Testing
@testable import lily

/// The head start Explore's lists give the position lookup before their first request.
@MainActor
struct HeadStartTests {
    private let sleep = HeldSleep()
    private let order = Steps()

    /// Work that answers in time runs `then` at once; the timer is cancelled, not waited for.
    @Test func workThatFinishesInTimeRunsThenAtOnce() async {
        await HeadStart.give(.seconds(1), sleep: sleep.sleep(for:)) {
            order.record(1)
        } then: {
            order.record(2)
        }

        #expect(order.entries == [1, 2])
        #expect(sleep.requested == [.seconds(1)] && sleep.held.isEmpty)
    }

    /// Work that takes longer is not cut short: `then` runs when the time is up, the work goes on and finishes.
    @Test func workThatTakesLongerGoesOnAfterThen() async {
        let hold = RequestHold()
        hold.isEnabled = true
        let run = Task {
            await HeadStart.give(.seconds(1), sleep: sleep.sleep(for:)) {
                await hold.wait()
                order.record(1)
            } then: {
                order.record(2)
            }
        }
        await settle(until: { sleep.held.count == 1 && hold.isHolding })
        #expect(order.entries.isEmpty)

        sleep.release()
        await settle(until: { order.entries == [2] })
        #expect(hold.isHolding, "the work was neither cancelled nor let go")

        hold.release()
        await run.value
        #expect(order.entries == [2, 1])
    }
}

/// What ran, in order.
@MainActor
private final class Steps {
    private(set) var entries: [Int] = []

    func record(_ number: Int) {
        entries.append(number)
    }
}
