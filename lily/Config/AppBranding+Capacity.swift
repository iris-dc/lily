import Foundation

/// Copy for a game that allows extra players, where the capacity is the number needed rather than a cap. In its own
/// file because `AppBranding` is at SwiftLint's type-body limit.
nonisolated extension AppBranding.Events {
    /// Under the capacity bar: `%ld` joined, `%ld` needed, whatever side of the number the game is on.
    static let joinedAndNeededFormat = "%ld joined \(separatorGlyph) %ld needed"
    /// Compact cards: `%ld` still needed, or `%ld` joined once the number is in.
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
    static let allowsExtraParticipants = "Allow extra players"
    static let allowsExtraParticipantsHint = "Anyone can still join once that many are in."

    /// The stepper's label: a cap, or the number needed when more may join past it.
    static func capacity(_ count: Int, needed: Bool) -> String {
        needed ? String(format: capacityNeededFormat, count) : capacity(count)
    }
}
