import Foundation

/// Parks callers until released, so a test can act while a request is observably in flight. A fake owns one per
/// operation it can hold, or conforms to `HoldsRequests` when a single hold parks everything. `waitOrThrow()` is for
/// a double of a URLSession-backed collaborator, `wait()` for a non-throwing protocol or detached work.
@MainActor
final class RequestHold {
    /// While true, `wait()` suspends every caller until `release()`.
    var isEnabled = false
    private var pending: [CheckedContinuation<Void, Never>] = []

    /// A caller held right now.
    var isHolding: Bool { !pending.isEmpty }

    /// Returns at once unless enabled; a cancelled caller is let through quietly.
    func wait() async {
        guard isEnabled else { return }
        await withCheckedContinuation { pending.append($0) }
    }

    /// A caller cancelled while held learns of it once the hold lifts, as a URLSession task does.
    func waitOrThrow() async throws {
        await wait()
        try Task.checkCancellation()
    }

    /// Lets every held caller through and stops holding new ones.
    func release() {
        isEnabled = false
        pending.forEach { $0.resume() }
        pending.removeAll()
    }
}

/// A fake that parks its requests on one hold; the conformance supplies `holdsRequests` and `releaseRequests()`.
@MainActor
protocol HoldsRequests: AnyObject {
    var hold: RequestHold { get }
}

extension HoldsRequests {
    /// While true, every held request records its call and then suspends until `releaseRequests()`.
    var holdsRequests: Bool {
        get { hold.isEnabled }
        set { hold.isEnabled = newValue }
    }

    /// A request held right now.
    var isHolding: Bool { hold.isHolding }

    /// Lets every held request through and stops holding new ones.
    func releaseRequests() {
        hold.release()
    }
}
