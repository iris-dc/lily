import Foundation

/// Gives `work` a head start of at most `timeout` before `then` runs, and lets it finish: `then` runs once `work` has
/// returned or the time has passed, whichever is first, and a `work` still running then goes on to its end. Nothing is
/// cancelled but the timer, where `Deadline.within` cancels the loser: Explore's lists give the position lookup a head
/// start so their first request carries it, and a fix that comes later still lands and reloads.
enum HeadStart {
    static func give(_ timeout: Duration,
                     sleep: @escaping Sleep = systemSleep,
                     to work: @escaping () async -> Void,
                     then: @escaping () async -> Void) async {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask { await work(); return true }
            group.addTask { try? await sleep(timeout); return false }
            if await group.next() == true { group.cancelAll() }
            await then()
        }
    }
}
