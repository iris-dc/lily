import Foundation

/// How experienced the host wants participants to be. Absent on an event means any level is welcome.
nonisolated enum SkillLevel: String, CaseIterable, Codable, Sendable {
    case beginner, intermediate, advanced

    var displayName: String { rawValue.capitalized }
}
