import Foundation

/// The backend's `type` field, value for value. `other` covers sports without a glyph of their own.
nonisolated enum SportType: String, CaseIterable, Codable, Sendable {
    case football, basketball, tennis, padel, running, volleyball, cycling, climbing, other

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
        case .other: "figure.mixed.cardio"
        }
    }
}
