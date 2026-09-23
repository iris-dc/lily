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
    private(set) var requested: [Duration] = []
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func sleep(for duration: Duration) async throws {
        requested.append(duration)
        try Task.checkCancellation()
        await withTaskCancellationHandler {
            await withCheckedContinuation { waiting.append($0) }
        } onCancel: {
            Task { @MainActor in self.release() }
        }
        try Task.checkCancellation()
    }

    /// Lets every held sleep finish.
    func release() {
        let sleepers = waiting
        waiting.removeAll()
        sleepers.forEach { $0.resume() }
    }
}
