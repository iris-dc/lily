import Foundation
import Testing
@testable import lily

/// A first page shows once the push has ended and its layout has gone quiet, or at the limit while it keeps changing;
/// a cached room shows at once, a loaded room with no rows too; one spinner covers the wait.
@MainActor
struct FirstPageRevealTests {
    private let sleep = HeldSleep()
    private let quiet = AppConfig.Chat.firstPageRevealQuiet
    private let limit = AppConfig.Chat.firstPageRevealLimit

    /// Hidden, and on screen already unless `arriving`: the push that brings it on still runs.
    private func makeSubject(isShown: Bool = false, arriving: Bool = false) -> FirstPageReveal {
        let subject = FirstPageReveal(isShown: isShown, sleep: { [sleep] in try await sleep.sleep(for: $0) })
        if !arriving { subject.arrived() }
        return subject
    }

    /// Notes a layout that shows the rows once settled, as the transcript's does, counting the calls.
    private func noteLayout(on subject: FirstPageReveal, hasRows: Bool = true, counting settled: Counter) {
        subject.noteLayout(hasRows: hasRows) {
            settled.value += 1
            subject.show()
        }
    }

    @Test func aShownTranscriptWaitsForNothing() async {
        let subject = makeSubject(isShown: true)
        let settled = Counter()

        noteLayout(on: subject, counting: settled)
        await Task.yield()

        #expect(sleep.requested.isEmpty && settled.value == 0)
    }

    @Test func aLayoutWithoutRowsStartsNoWait() async {
        let subject = makeSubject()
        let settled = Counter()

        noteLayout(on: subject, hasRows: false, counting: settled)
        await Task.yield()

        #expect(sleep.requested.isEmpty && !subject.isShown)
    }

    @Test func theRowsShowOnceTheLayoutIsQuiet() async {
        let subject = makeSubject()
        let settled = Counter()

        noteLayout(on: subject, counting: settled)
        await settle(until: { sleep.held.sorted() == [quiet, limit] })
        sleep.release { $0 == quiet }
        await settle(until: { subject.isShown })

        #expect(settled.value == 1)
        await settle(until: { sleep.held.isEmpty })
        #expect(settled.value == 1, "the limit, cancelled by the show, settles nothing more")
    }

    @Test func aLaterLayoutRestartsTheQuietButNotTheLimit() async {
        let subject = makeSubject()
        let settled = Counter()

        noteLayout(on: subject, counting: settled)
        await settle(until: { sleep.held.count == 2 })
        noteLayout(on: subject, counting: settled)
        await settle(until: { sleep.requested.count == 3 && sleep.held.count == 2 })

        #expect(sleep.requested.filter { $0 == limit }.count == 1, "one limit, counted from the first layout")
        #expect(!subject.isShown, "the cancelled quiet settles nothing")
        sleep.release { $0 == quiet }
        await settle(until: { subject.isShown })
        #expect(settled.value == 1)
    }

    @Test func theLimitShowsALayoutThatKeepsChanging() async {
        let subject = makeSubject()
        let settled = Counter()

        noteLayout(on: subject, counting: settled)
        await settle(until: { sleep.held.count == 2 })
        sleep.release { $0 == limit }
        await settle(until: { subject.isShown })

        #expect(settled.value == 1)
    }

    @Test func theLatestClosureIsTheOneRun() async {
        let subject = makeSubject()
        let first = Counter()
        let latest = Counter()

        noteLayout(on: subject, counting: first)
        await settle(until: { sleep.held.count == 2 })
        noteLayout(on: subject, counting: latest)
        await settle(until: { sleep.requested.count == 3 && sleep.held.count == 2 })
        sleep.release { $0 == limit }
        await settle(until: { subject.isShown })

        #expect(first.value == 0 && latest.value == 1, "the limit from the first layout runs the latest closure")
    }

    @Test func showingAtOnceCancelsTheWaits() async {
        let subject = makeSubject()
        let settled = Counter()

        noteLayout(on: subject, counting: settled)
        await settle(until: { sleep.held.count == 2 })
        subject.show()
        await settle(until: { sleep.held.isEmpty })

        #expect(subject.isShown && settled.value == 0)
        noteLayout(on: subject, counting: settled)
        await Task.yield()
        #expect(sleep.requested.count == 2, "a shown transcript waits for nothing more")
    }

    /// The page landed during the push, which still draws the scroll view where it took it: the rows wait for its end.
    @Test func aLayoutQuietDuringThePushShowsWhenThePushEnds() async {
        let subject = makeSubject(arriving: true)
        let settled = Counter()

        noteLayout(on: subject, counting: settled)
        await settle(until: { sleep.held.count == 2 })
        sleep.release { $0 == quiet }
        await settle(until: { subject.isSettled })
        #expect(!subject.isShown, "quiet, but the push still runs")

        subject.arrived()

        #expect(subject.isShown && settled.value == 1)
    }

    @Test func aLayoutStillChangingAsThePushEndsWaitsForTheQuiet() async {
        let subject = makeSubject(arriving: true)
        let settled = Counter()

        noteLayout(on: subject, counting: settled)
        await settle(until: { sleep.held.count == 2 })
        subject.arrived()
        #expect(!subject.isShown)

        sleep.release { $0 == quiet }
        await settle(until: { subject.isShown })
        #expect(settled.value == 1)
    }

    /// The limit is a ceiling: a push whose end never comes keeps nothing hidden for good.
    @Test func theLimitShowsEvenDuringThePush() async {
        let subject = makeSubject(arriving: true)
        let settled = Counter()

        noteLayout(on: subject, counting: settled)
        await settle(until: { sleep.held.count == 2 })
        sleep.release { $0 == limit }
        await settle(until: { subject.isShown })

        #expect(settled.value == 1)
    }

    /// Covered by another screen while hidden, the transcript waits for the pop that brings it back as for the push.
    @Test func aDepartureMakesTheWayBackATransitionToWaitFor() async {
        let subject = makeSubject()
        let settled = Counter()
        subject.departed()

        noteLayout(on: subject, counting: settled)
        await settle(until: { sleep.held.count == 2 })
        sleep.release { $0 == quiet }
        await settle(until: { subject.isSettled })
        #expect(!subject.isShown, "quiet, but the pop still runs")

        subject.arrived()
        #expect(subject.isShown && settled.value == 1)
    }

    @Test func anEndedLoadShowsALoadedEmptyRoomAtOnceAndKeepsAFailedOneHidden() {
        let loaded = makeSubject()
        loaded.historyEnded(hasRows: false, loaded: true) {}
        let failed = makeSubject()
        failed.historyEnded(hasRows: false, loaded: false) {}

        #expect(loaded.isShown && !failed.isShown, "Try again's page will settle out of sight")
        #expect(sleep.requested.isEmpty)
    }

    /// Rows already laid out (a pending send) may not change when the page lands: the end of the load starts the wait.
    @Test func anEndedLoadWithRowsWaitsForTheLayoutToGoQuiet() async {
        let subject = makeSubject()
        let settled = Counter()

        subject.historyEnded(hasRows: true, loaded: false) {
            settled.value += 1
            subject.show()
        }
        await settle(until: { sleep.held.sorted() == [quiet, limit] })
        #expect(!subject.isShown)
        sleep.release { $0 == quiet }
        await settle(until: { subject.isShown })

        #expect(settled.value == 1)
    }

    @Test func oneSpinnerCoversTheLoadAndTheSettling() {
        let subject = makeSubject()

        #expect(subject.showsSpinner(hasRows: false, isAwaitingHistory: true), "the page is on its way")
        #expect(!subject.showsSpinner(hasRows: false, isAwaitingHistory: false), "the empty state or Try again shows")
        #expect(subject.showsSpinner(hasRows: true, isAwaitingHistory: false), "the rows settle out of sight")
        subject.show()
        #expect(!subject.showsSpinner(hasRows: true, isAwaitingHistory: false))
        #expect(subject.showsSpinner(hasRows: false, isAwaitingHistory: true), "Try again's load, rows or not shown")
    }
}

@MainActor
private final class Counter {
    var value = 0
}
