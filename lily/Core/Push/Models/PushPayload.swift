import Foundation

/// Reads the notification payload the backend sends; the one place that knows its keys.
nonisolated enum PushPayload {
    /// The game a reminder notification is about, or `nil` for any other payload.
    static func eventID(from userInfo: [AnyHashable: Any]) -> String? {
        let keys = AppConfig.Push.Payload.self
        guard userInfo[keys.kind] as? String == keys.eventReminder,
              let eventID = userInfo[keys.eventID] as? String, !eventID.isEmpty else { return nil }
        return eventID
    }
}
