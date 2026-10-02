import Foundation

/// Copy for the player limit: a game that allows extra players, where the capacity is the number needed rather than a
/// cap, and one without any limit. In its own file because `AppBranding` is at SwiftLint's type-body limit.
nonisolated extension AppBranding.Events {
    /// Under the capacity bar: `%ld` joined, `%ld` needed, whatever side of the number the game is on.
    static let joinedAndNeededFormat = "%ld joined \(separatorGlyph) %ld needed"
    /// Compact cards: `%ld` still needed, or `%ld` joined once the number is in; the count alone is also all a game
    /// without a limit has to say.
    static let moreNeededFormat = "%ld more needed"
    static let joinedCountFormat = "%ld joined"

    static func joined(_ count: Int, needed capacity: Int) -> String {
        String(format: joinedAndNeededFormat, count, capacity)
    }

    static func moreNeeded(_ count: Int) -> String {
        String(format: moreNeededFormat, count)
    }

    static func joinedCount(_ count: Int) -> String {
        String(format: joinedCountFormat, count)
    }
}

nonisolated extension AppBranding.Events.Create {
    /// Stepper label once extras are allowed: `%ld` is the number of players needed, the host included.
    static let capacityNeededFormat = "%ld players needed"
    /// The segments of the player-limit picker, in `PlayerLimit.allCases` order.
    static let unlimitedPlayers = "Any number"
    static let maximumPlayers = "Up to"
    static let minimumPlayers = "At least"
    static let unlimitedHint = "No limit: anyone can join."
    static let minimumHint = "Anyone can still join once that many are in."

    /// The stepper's label: a cap, or the number needed when more may join past it.
    static func capacity(_ count: Int, needed: Bool) -> String {
        needed ? String(format: capacityNeededFormat, count) : capacity(count)
    }

    static func name(for limit: PlayerLimit) -> String {
        switch limit {
        case .unlimited: unlimitedPlayers
        case .maximum: maximumPlayers
        case .minimum: minimumPlayers
        }
    }

    /// What the Players footer explains for the choice; a cap needs no explanation.
    static func hint(for limit: PlayerLimit) -> String? {
        switch limit {
        case .unlimited: unlimitedHint
        case .maximum: nil
        case .minimum: minimumHint
        }
    }
}
