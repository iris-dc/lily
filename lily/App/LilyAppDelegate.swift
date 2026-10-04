import UIKit
import UserNotifications

/// The UIKit callbacks SwiftUI has no modifier for: the APNs token (or its refusal) and notification taps, posted to
/// `PushEventRelay` because this object is created before the composition root exists.
final class LilyAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushEventRelay.shared.deliver(token: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        PushEventRelay.shared.fail(error)
    }
}

extension LilyAppDelegate: UNUserNotificationCenterDelegate {
    /// A reminder that arrives while the app is open still shows as a banner; the inbox updates on its own sync.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    /// Only the ids cross to the main actor, as a `PushTap`: the payload dictionary is not `Sendable`.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let tap = PushPayload.tap(from: response.notification.request.content.userInfo)
        Task { @MainActor in
            if let tap { PushEventRelay.shared.notificationTapped(tap) }
            completionHandler()
        }
    }
}
