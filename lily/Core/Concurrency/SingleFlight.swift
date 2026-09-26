import Observation

/// One run of a piece of work at a time: a call made while one is in flight joins it instead of starting another. The
/// work runs in a task of its own, so a caller cancelled mid-flight (the shell's sync when the scene phase changes)
/// does not take the request down with it. Observable so a screen can follow `isRunning`.
@Observable
final class SingleFlight {
    private var task: Task<Void, Never>?

    var isRunning: Bool { task != nil }

    func run(_ work: @escaping () async -> Void) async {
        if let task {
            await task.value
            return
        }
        let started = Task {
            defer { task = nil }
            await work()
        }
        task = started
        await started.value
    }
}
