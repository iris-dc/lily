import Foundation

/// Where the app delegate's push callbacks land: the device token (or the refusal) for whoever is waiting on
/// `registerForRemoteNotifications`, and a tapped notification's game for the coordinator. The delegate is created by
/// SwiftUI before the composition root exists, so it posts to the shared relay and the coordinator subscribes.
final class PushEventRelay {
    static let shared = PushEventRelay()

    /// Set by the coordinator; a tap that arrives before it is set waits here.
    var tapHandler: ((String) -> Void)? {
        didSet {
            guard let tapHandler, let pendingEventID else { return }
            self.pendingEventID = nil
            tapHandler(pendingEventID)
        }
    }
    private var pendingEventID: String?
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

    /// A notification was tapped for `eventID`; handed on at once, or kept until the coordinator subscribes.
    func notificationTapped(eventID: String) {
        if let tapHandler {
            tapHandler(eventID)
        } else {
            pendingEventID = eventID
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
