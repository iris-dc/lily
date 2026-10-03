import Foundation

/// Copy for the player limit: a game that allows extra players, where the capacity is the number needed rather than a
/// cap, and one without any limit. In its own file because `AppBranding` is at SwiftLint's type-body limit.
nonisolated extension AppBranding.Events {
    /// Under the capacity bar: joined and needed, whatever side of the number the game is on.
    static func joined(_ count: Int, needed capacity: Int) -> String {
        localized("\(count) joined · \(capacity) needed")
    }

    /// Compact cards: still needed, or joined once the number is in; the count alone is also all a game without a
    /// limit has to say.
    static func moreNeeded(_ count: Int) -> String {
        localized("\(count) more needed")
    }

    static func joinedCount(_ count: Int) -> String {
        localized("\(count) joined")
    }
}

nonisolated extension AppBranding.Events.Create {
    /// The segments of the player-limit picker, in `PlayerLimit.allCases` order.
    static var unlimitedPlayers: String { localized("Any number") }
    static var maximumPlayers: String { localized("Up to") }
    static var minimumPlayers: String { localized("At least") }
    static var unlimitedHint: String { localized("No limit: anyone can join.") }
    static var minimumHint: String { localized("Anyone can still join once that many are in.") }

    /// The stepper's label: a cap, or the number needed when more may join past it.
    static func capacity(_ count: Int, needed: Bool) -> String {
        needed ? localized("\(count) players needed") : capacity(count)
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
