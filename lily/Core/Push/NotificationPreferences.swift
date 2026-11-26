import Foundation
import Observation

/// Which push kinds this device asked not to receive. The mute is per device, like the system permission it refines,
/// so it lives in `UserDefaults` and rides to the backend with every device registration, which stores it on the
/// device row; the push sender reads it there, so a muted kind is never sent to this device.
@Observable
final class NotificationPreferences {
    private(set) var mutedKinds: Set<NotificationKind>
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: AppConfig.Push.mutedKindsKey) ?? []
        mutedKinds = Set(stored.compactMap(NotificationKind.init(rawValue:)))
    }

    func isEnabled(_ kind: NotificationKind) -> Bool {
        !mutedKinds.contains(kind)
    }

    func set(_ kind: NotificationKind, enabled: Bool) {
        if enabled {
            mutedKinds.remove(kind)
        } else {
            mutedKinds.insert(kind)
        }
        defaults.set(mutedWireNames, forKey: AppConfig.Push.mutedKindsKey)
    }

    /// Sorted, so two registrations carrying the same mutes compare equal.
    var mutedWireNames: [String] {
        mutedKinds.map(\.wireName).sorted()
    }
}
