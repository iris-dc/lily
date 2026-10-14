import Observation

/// One run of a piece of work at a time, keyed by what the run is for. A call for the same key, or one made without a
/// key, joins the run in flight instead of starting another; a call for another key waits it out and then starts its
/// own, so a store keyed by user never hands one caller's request to another. The work runs in a task of its own, so a
/// caller cancelled mid-flight (the shell's sync when the scene phase changes) does not take the request down with
/// it. Observable so a screen can follow `isRunning`.
@Observable
final class SingleFlight {
    private var task: Task<Void, Never>?
    /// What the run in flight is for; `nil` for an unkeyed run.
    private var runningKey: AnyHashable?

    var isRunning: Bool { task != nil }

    func run(key: AnyHashable? = nil, _ work: @escaping () async -> Void) async {
        // Decided before the await: once the run ended, `runningKey` is nil again. The loop re-reads `task` because
        // another waiter woken by the same completion may have started a run meanwhile.
        while let inFlight = task {
            let joins = key == nil || runningKey == key
            await inFlight.value
            if joins { return }
        }
        runningKey = key
        let started = Task { [self] in
            defer {
                task = nil
                runningKey = nil
            }
            await work()
        }
        task = started
        await started.value
    }
}
