import Foundation

/// Where the app delegate's push callbacks land: the device token (or the refusal) for whoever is waiting on
/// `registerForRemoteNotifications`, and a tapped notification's target for the coordinator. The delegate is created
/// by SwiftUI before the composition root exists, so it posts to the shared relay and the coordinator subscribes.
final class PushEventRelay {
    static let shared = PushEventRelay()

    /// Set by the coordinator; a tap that arrives before it is set waits here.
    var tapHandler: ((PushTap) -> Void)? {
        didSet {
            guard let tapHandler, let pendingTap else { return }
            self.pendingTap = nil
            tapHandler(pendingTap)
        }
    }
    private var pendingTap: PushTap?
    private var waiters: [Waiter] = []

    /// Whether a registration is waiting for the system's answer.
    var isWaiting: Bool { !waiters.isEmpty }

    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<String, any Error>
    }

    /// Runs `register` (the system call) and waits for the token it answers with, or its refusal, or `timeout`.
    func token(timeout: Duration, register: () -> Void) async throws -> String {
        let id = UUID()
        return try await withCheckedThrowingContinuation { continuation in
            waiters.append(Waiter(id: id, continuation: continuation))
            register()
            Task { [weak self] in
                try? await Task.sleep(for: timeout)
                self?.resume(id, with: .failure(PushRegistrationError.timedOut))
            }
        }
    }

    /// `didRegisterForRemoteNotificationsWithDeviceToken`: the raw token, answered to every waiter as hex.
    func deliver(token: Data) {
        resumeAll(with: .success(token.map { String(format: "%02x", $0) }.joined()))
    }

    /// `didFailToRegisterForRemoteNotifications`.
    func fail(_ error: any Error) {
        resumeAll(with: .failure(PushRegistrationError.refused(error.localizedDescription)))
    }

    /// A notification was tapped; handed on at once, or kept until the coordinator subscribes.
    func notificationTapped(_ tap: PushTap) {
        if let tapHandler {
            tapHandler(tap)
        } else {
            pendingTap = tap
        }
    }

    private func resumeAll(with result: Result<String, any Error>) {
        let resumed = waiters
        waiters.removeAll()
        resumed.forEach { $0.continuation.resume(with: result) }
    }

    private func resume(_ id: UUID, with result: Result<String, any Error>) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(with: result)
    }
}
