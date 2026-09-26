import Foundation

/// Parks callers until released, so a test can act while a request is observably in flight. A fake owns one per
/// operation it can hold and forwards its `holdsRequests`/`releaseRequests()` to it.
@MainActor
final class RequestHold {
    /// While true, `wait()` suspends every caller until `release()`.
    var isEnabled = false
    private var pending: [CheckedContinuation<Void, Never>] = []

    /// A caller held right now.
    var isHolding: Bool { !pending.isEmpty }

    /// Returns at once unless enabled.
    func wait() async {
        guard isEnabled else { return }
        await withCheckedContinuation { pending.append($0) }
    }

    /// Lets every held caller through and stops holding new ones.
    func release() {
        isEnabled = false
        pending.forEach { $0.resume() }
        pending.removeAll()
    }
}
