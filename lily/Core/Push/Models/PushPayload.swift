import Foundation

/// What a tapped notification asks the app to open; built from the payload's strings alone, so the delegate can hand
/// it to the main actor.
nonisolated enum PushTap: Hashable, Sendable {
    /// A game reminder: the game's detail.
    case event(id: String)
    /// A match reminder: the tournament's detail with that match's sheet up.
    case match(tournamentID: String, matchID: String)

    /// For log lines: ids only.
    var logName: String {
        switch self {
        case .event(let id): "event \(id)"
        case .match(let tournamentID, let matchID): "match \(matchID) of tournament \(tournamentID)"
        }
    }
}

/// Reads the notification payload the backend sends; the one place that knows its keys.
nonisolated enum PushPayload {
    /// The tap a reminder notification asks for, or `nil` for any other payload or one missing its ids.
    static func tap(from userInfo: [AnyHashable: Any]) -> PushTap? {
        let keys = AppConfig.Push.Payload.self
        switch userInfo[keys.kind] as? String {
        case keys.eventReminder:
            return value(userInfo, keys.eventID).map { .event(id: $0) }
        case keys.matchReminder:
            guard let tournamentID = value(userInfo, keys.tournamentID), let matchID = value(userInfo, keys.matchID) else {
                return nil
            }
            return .match(tournamentID: tournamentID, matchID: matchID)
        default:
            return nil
        }
    }

    private static func value(_ userInfo: [AnyHashable: Any], _ key: String) -> String? {
        guard let value = userInfo[key] as? String, !value.isEmpty else { return nil }
        return value
    }
}
