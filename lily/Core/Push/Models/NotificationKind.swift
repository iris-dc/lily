import Foundation

/// A push the backend may send, as Settings' Notifications screen names it; the raw values are Laurel's payload kinds
/// (`AppConfig.Push.Payload`). The inbox keeps its items regardless: a mute silences the banner, never the record.
nonisolated enum NotificationKind: String, CaseIterable, Sendable {
    case eventReminder = "event_reminder"
    case matchReminder = "match_reminder"
    case eventCancelled = "event_cancelled"

    /// The `kind` the backend's payload and the device row's mutes carry.
    var wireName: String { rawValue }
}
