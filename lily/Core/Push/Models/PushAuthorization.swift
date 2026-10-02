import Foundation

/// The notification permission as the app reads it: not asked yet, refused, or granted (provisional counts as granted).
nonisolated enum PushAuthorization: Sendable {
    case notDetermined
    case denied
    case authorized
}

/// Why the system handed over no device token.
nonisolated enum PushRegistrationError: Error, Equatable, Sendable {
    /// `didFailToRegisterForRemoteNotifications`: no entitlement, or no connection to APNs.
    case refused(String)
    /// Neither callback came within `AppConfig.Push.tokenTimeout`.
    case timedOut
}
