import Foundation
import Synchronization

/// `URLSession.data(from:)` with the task's `Progress` reported along the way, which the convenience API offers no hook
/// for, and the task cancelled with the caller. The data arrives whole at the end like the convenience API's; the
/// progress is the share of the response's declared length received so far (nothing while the length is unknown).
nonisolated enum ProgressDataTask {
    static func run(_ url: URL,
                    in session: URLSession,
                    progress report: (@MainActor @Sendable (Double) -> Void)?) async throws -> (Data, URLResponse) {
        let handle = TaskHandle()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = session.dataTask(with: url) { data, response, error in
                    handle.finish()
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let data, let response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                }
                let observation = report.map { report in
                    task.progress.observe(\.fractionCompleted) { progress, _ in
                        let fraction = progress.fractionCompleted
                        Task { @MainActor in report(fraction) }
                    }
                }
                handle.start(task, observation: observation)
            }
        } onCancel: {
            handle.cancel()
        }
    }
}

/// The running task and its observation, so a cancellation that lands before or after the task started is honoured
/// and the observation lives exactly as long as the task.
nonisolated private final class TaskHandle: Sendable {
    private struct State {
        var task: URLSessionTask?
        var observation: NSKeyValueObservation?
        var isCancelled = false
    }

    private let state = Mutex(State())

    func start(_ task: URLSessionTask, observation: NSKeyValueObservation?) {
        let cancelled = state.withLock { state in
            state.task = task
            state.observation = observation
            return state.isCancelled
        }
        if cancelled {
            task.cancel()
        } else {
            task.resume()
        }
    }

    func cancel() {
        let task = state.withLock { state in
            state.isCancelled = true
            return state.task
        }
        task?.cancel()
    }

    func finish() {
        let observation = state.withLock { state in
            let observation = state.observation
            state.observation = nil
            return observation
        }
        observation?.invalidate()
    }
}
