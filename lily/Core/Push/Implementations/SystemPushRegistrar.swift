import UIKit
import UserNotifications

/// `UNUserNotificationCenter` and `UIApplication.registerForRemoteNotifications`, answered through the relay the app
/// delegate feeds. A refusal (a simulator or a build without the push entitlement, no network) is an error the
/// coordinator logs, never a popup.
final class SystemPushRegistrar: PushRegistrar {
    private let center = UNUserNotificationCenter.current()
    private let relay: PushEventRelay
    private let logger: any Logging

    init(relay: PushEventRelay = .shared, logger: any Logging) {
        self.relay = relay
        self.logger = logger
    }

    func authorization() async -> PushAuthorization {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized, .provisional, .ephemeral: .authorized
        @unknown default: .denied
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.warning(.push, "Notification permission request failed: \(error)")
            return false
        }
    }

    func deviceToken() async throws -> String {
        try await relay.token(timeout: AppConfig.Push.tokenTimeout) {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}
