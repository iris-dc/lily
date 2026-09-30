import Foundation

/// What kind of game an event is. `other` covers anything the list does not name yet.
nonisolated enum EventType: String, CaseIterable, Codable, Sendable {
    case football, basketball, tennis, padel, running, volleyball, cycling, climbing, yoga, other

    var displayName: String { rawValue.capitalized }

    var symbolName: String {
        switch self {
        case .football: "figure.indoor.soccer"
        case .basketball: "figure.basketball"
        case .tennis: "figure.tennis"
        case .padel: "figure.pickleball"
        case .running: "figure.run"
        case .volleyball: "figure.volleyball"
        case .cycling: "figure.outdoor.cycle"
        case .climbing: "figure.climbing"
        case .yoga: "figure.yoga"
        case .other: "figure.mixed.cardio"
        }
    }
}
