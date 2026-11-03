import Foundation

/// The hour and the day a fixture, a preview or a config value is built from, so no other file under `lily/` spells 3600
/// or 86 400 itself.
nonisolated extension TimeInterval {
    static let hour: TimeInterval = 3600
    static let day: TimeInterval = 86_400
}
