import Foundation
import Observation

/// Settings' Notifications screen: the system permission's state and the per-kind switches. The mutes live on this
/// device (`NotificationPreferences`) and ride to the backend with the device registration, so a flip re-registers
/// through `PushSyncing`; the permission itself is the system's, re-read whenever the app returns active.
@Observable
final class NotificationsViewModel {
    /// `nil` until the first read answers; the screen shows a spinner that long.
    private(set) var authorization: PushAuthorization?
    /// The re-registration a flip started; the screen never waits on it, tests do.
    private(set) var syncTask: Task<Void, Never>?

    private let registrar: any PushRegistrar
    private let preferences: NotificationPreferences
    private let optIn: any PushOptIn
    private let pushSync: any PushSyncing
    private let logger: any Logging

    init(registrar: any PushRegistrar,
         preferences: NotificationPreferences,
         optIn: any PushOptIn,
         pushSync: any PushSyncing,
         logger: any Logging) {
        self.registrar = registrar
        self.preferences = preferences
        self.optIn = optIn
        self.pushSync = pushSync
        self.logger = logger
    }

    /// On appear and whenever the app returns active: the user may have flipped the permission in the system settings.
    func refresh() async {
        authorization = await registrar.authorization()
    }

    /// The system prompt, from the screen's own button; a grant registers the device at once (the opt-in does).
    func enable() async {
        await optIn.offerReminders()
        await refresh()
    }

    func isEnabled(_ kind: NotificationKind) -> Bool {
        preferences.isEnabled(kind)
    }

    /// Persists the flip and re-registers, so the backend's device row carries the new mutes before the next sweep.
    func set(_ kind: NotificationKind, enabled: Bool) {
        guard preferences.isEnabled(kind) != enabled else { return }
        preferences.set(kind, enabled: enabled)
        logger.info(.push, "Notification kind \(kind.wireName) \(enabled ? "enabled" : "muted")")
        syncTask = Task { await pushSync.sync() }
    }
}
