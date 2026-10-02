import Foundation

/// How a game limits who joins: not at all, up to a cap, or a number it needs with more welcome. The wire carries an
/// optional `capacity` plus `allowsExtraParticipants`; this is the one place those two become three states.
nonisolated enum PlayerLimit: Hashable, CaseIterable, Sendable {
    /// No capacity at all; anyone joins.
    case unlimited
    /// The capacity is a cap: the game is full once it is reached.
    case maximum
    /// The capacity is the number needed; more may still join.
    case minimum

    init(capacity: Int?, allowsExtraParticipants: Bool) {
        if capacity == nil {
            self = .unlimited
        } else {
            self = allowsExtraParticipants ? .minimum : .maximum
        }
    }

    var hasCapacity: Bool { self != .unlimited }
    var allowsExtraParticipants: Bool { self == .minimum }
}
