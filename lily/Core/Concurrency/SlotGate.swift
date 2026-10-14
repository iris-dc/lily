import Foundation

/// At most `limit` pieces of work at a time, the rest waiting in order. A waiter whose task is cancelled leaves the
/// queue at once without a slot, so an owner that dies with uploads queued leaks no continuation and keeps no slot.
final class SlotGate {
    private let limit: Int
    private(set) var active = 0
    private var waiters: [(id: UUID, continuation: CheckedContinuation<Void, any Error>)] = []

    var waiting: Int { waiters.count }

    init(limit: Int) {
        self.limit = limit
    }

    /// Returns holding a slot, or throws `CancellationError` when cancelled before one came; every return is paired
    /// with `release()`.
    func acquire() async throws {
        try Task.checkCancellation()
        if active < limit {
            active += 1
            return
        }
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                waiters.append((id: id, continuation: continuation))
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancelWaiter(id) }
        }
    }

    /// Hands the slot to the next waiter, who keeps the count, or frees it.
    func release() {
        if waiters.isEmpty {
            active -= 1
        } else {
            waiters.removeFirst().continuation.resume()
        }
    }

    /// Takes a cancelled waiter out of the queue, throwing; nothing when a slot reached it first (the waiter then
    /// returns holding it and releases it itself).
    private func cancelWaiter(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}
