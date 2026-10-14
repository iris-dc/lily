/// Work that must run off the main actor but die with its caller: `try await Task.detached {...}.value` severs
/// cancellation, so a composer slot removed mid-export would let the export run on. The detached task is cancelled with
/// the awaiting one and never started for a caller already cancelled; the work still decides where it checks. It is
/// `@concurrent` so a closure formed on the main actor cannot be inferred as isolated to it and hop back.
nonisolated enum DetachedWork {
    static func run<T: Sendable>(priority: TaskPriority = .userInitiated,
                                 _ work: @escaping @Sendable @concurrent () async throws -> T) async throws -> T {
        try Task.checkCancellation()
        let task = Task.detached(priority: priority) { try await work() }
        return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }
}
