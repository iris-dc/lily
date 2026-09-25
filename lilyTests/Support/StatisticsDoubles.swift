import Foundation
@testable import lily

/// Records what the screens report and how often they ask for a flush.
@MainActor
final class SpyInteractionRecorder: InteractionRecorder {
    private(set) var interactions: [Interaction] = []
    private(set) var flushCount = 0

    var kinds: [InteractionKind] { interactions.map(\.kind) }

    func record(_ interaction: Interaction) {
        interactions.append(interaction)
    }

    func flush() async {
        flushCount += 1
    }
}

/// A sleep that holds until released, so a timer can be fired or cancelled on cue instead of waiting on a clock.
/// A cancelled sleeper is released too and throws, like `Task.sleep`.
@MainActor
final class HeldSleep {
    private struct Sleeper {
        let id: UUID
        let duration: Duration
        let continuation: CheckedContinuation<Void, Never>
    }

    private(set) var requested: [Duration] = []
    private var waiting: [Sleeper] = []

    /// The durations still being slept on.
    var held: [Duration] { waiting.map(\.duration) }

    func sleep(for duration: Duration) async throws {
        requested.append(duration)
        try Task.checkCancellation()
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { waiting.append(Sleeper(id: id, duration: duration, continuation: $0)) }
        } onCancel: {
            Task { @MainActor in self.release(id: id) }
        }
        try Task.checkCancellation()
    }

    /// Lets every held sleep finish.
    func release() {
        release { _ in true }
    }

    /// Lets the held sleeps matching `predicate` finish; the others keep waiting.
    func release(where predicate: (Duration) -> Bool) {
        let released = waiting.filter { predicate($0.duration) }
        waiting.removeAll { predicate($0.duration) }
        released.forEach { $0.continuation.resume() }
    }

    /// A cancelled sleeper wakes alone; every other held sleep keeps waiting.
    private func release(id: UUID) {
        guard let index = waiting.firstIndex(where: { $0.id == id }) else { return }
        waiting.remove(at: index).continuation.resume()
    }
}
