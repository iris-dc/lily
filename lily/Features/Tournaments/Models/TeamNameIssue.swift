import Foundation

/// What keeps a team's name from being sent, judged against `AppConfig.Tournaments.teamNameLength`.
nonisolated enum TeamNameIssue: Hashable, Sendable {
    case tooShort
    case tooLong

    static func issue(in name: String) -> TeamNameIssue? {
        let length = name.trimmed.wireLength
        let limits = AppConfig.Tournaments.teamNameLength
        if length < limits.lowerBound { return .tooShort }
        if length > limits.upperBound { return .tooLong }
        return nil
    }
}
