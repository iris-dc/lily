import Foundation

nonisolated extension AppBranding {
    /// Copy of Settings' Notifications screen: the link row, the permission states and the per-kind switches.
    enum Notifications {
        /// The screen's title and the link row on Settings that opens it.
        static var title: String { localized("Notifications") }
        /// Under the link row's title: what the screen manages.
        static var rowSubtitle: String { localized("Which reminders reach this device") }
        /// Over the enable button, while the system has never been asked.
        static var notDeterminedMessage: String {
            localized("Get a reminder an hour before your events and tournament matches.")
        }
        static var enableAction: String { localized("Enable notifications") }
        /// When the system permission was declined: the only way back is the system settings.
        static var deniedMessage: String {
            localized("Notifications for iskra are turned off in the system settings.")
        }
        static var openSettingsAction: String { localized("Open Settings") }

        static func title(for kind: NotificationKind) -> String {
            switch kind {
            case .eventReminder: localized("Event reminders")
            case .matchReminder: localized("Match reminders")
            case .eventCancelled: localized("Cancelled events")
            }
        }

        static func caption(for kind: NotificationKind) -> String {
            switch kind {
            case .eventReminder: localized("An hour before an event you joined")
            case .matchReminder: localized("An hour before your tournament match")
            case .eventCancelled: localized("When an event you joined is cancelled")
            }
        }
    }
}
