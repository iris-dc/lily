import Foundation

/// How a tournament's matches are drawn: a bracket where a loss is the end (byes to the next power of two, seed 1
/// meets seed N), or everyone against everyone (the circle method). Fixed once the tournament exists; it decides how
/// many entries may enter. Snake case on the wire, like the backend's constant names lower-cased.
nonisolated enum TournamentFormat: String, CaseIterable, Codable, Sendable {
    case singleElimination = "single_elimination"
    case roundRobin = "round_robin"

    var displayName: String {
        switch self {
        case .singleElimination: AppBranding.Tournaments.singleElimination
        case .roundRobin: AppBranding.Tournaments.roundRobin
        }
    }

    var entriesRange: ClosedRange<Int> { AppConfig.Tournaments.entriesRange(for: self) }
    var minimumEntriesToStart: Int { AppConfig.Tournaments.minEntries(for: self) }
}

/// Where a tournament stands: entries join and leave while in `registration`, the organiser starts it by hand, the
/// final's result completes it, and the organiser may cancel it before that.
nonisolated enum TournamentStatus: String, CaseIterable, Codable, Sendable {
    case registration
    case inProgress = "in_progress"
    case completed
    case cancelled

    var displayName: String {
        switch self {
        case .registration: AppBranding.Tournaments.registrationStatus
        case .inProgress: AppBranding.Tournaments.inProgressStatus
        case .completed: AppBranding.Tournaments.completedStatus
        case .cancelled: AppBranding.Tournaments.cancelledStatus
        }
    }

    /// Nothing more happens to a completed or cancelled tournament.
    var isOver: Bool { self == .completed || self == .cancelled }
}

/// An entry's standing: `withdrawn` is kept for an entry taken out after the start, which the bracket must still name.
nonisolated enum EntryStatus: String, Codable, Sendable {
    case registered, withdrawn
}

/// Where a match stands: waiting for its sides or a result, given a time and place, a score one side reported, a
/// score both sides (or the organiser) stand behind, a no-show the organiser recorded, or a first-round bye.
nonisolated enum MatchStatus: String, Codable, Sendable {
    case pending, scheduled, reported, confirmed, walkover, bye

    /// A result nobody can change but the organiser.
    var isDecided: Bool { self == .confirmed || self == .walkover || self == .bye }
    /// Waiting for a result, with or without a time.
    var isOpen: Bool { self == .pending || self == .scheduled }
}

/// Which side of the next match a winner advances into.
nonisolated enum MatchSlot: String, Codable, Sendable {
    case a, b
}
