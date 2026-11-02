import Foundation

/// How a tournament's matches are drawn: a bracket where a loss is the end (byes to the next power of two, seed 1
/// meets seed N), or everyone against everyone (the circle method). Fixed once the tournament exists; it decides how
/// many entries may enter. Snake case on the wire, like the backend's constant names lower-cased. A format a newer
/// backend sends is kept by name: it draws neither a bracket nor a table, takes the widest entries range and shows
/// its raw name, so a page or a detail carrying it still decodes.
nonisolated enum TournamentFormat: WireNamedKind {
    case singleElimination
    case roundRobin
    case unknown(String)

    /// The formats the draft form offers.
    static let known: [TournamentFormat] = [.singleElimination, .roundRobin]

    private static let singleEliminationName = "single_elimination"
    private static let roundRobinName = "round_robin"

    var wireName: String {
        switch self {
        case .singleElimination: Self.singleEliminationName
        case .roundRobin: Self.roundRobinName
        case .unknown(let name): name
        }
    }

    var displayName: String {
        switch self {
        case .singleElimination: AppBranding.Tournaments.singleElimination
        case .roundRobin: AppBranding.Tournaments.roundRobin
        case .unknown(let name): name
        }
    }

    var entriesRange: ClosedRange<Int> { AppConfig.Tournaments.entriesRange(for: self) }
    var minimumEntriesToStart: Int { AppConfig.Tournaments.minEntries(for: self) }
    /// A knockout is drawn as a bracket; everyone-against-everyone as a standings table.
    var drawsBracket: Bool { self == .singleElimination }
}

/// Where a tournament stands: entries join and leave while in `registration`, the organiser starts it by hand, the
/// final's result completes it, and the organiser may cancel it before that. A status a newer backend sends is kept by
/// name: the tournament is neither listed, startable nor over, and its chip shows the raw name.
nonisolated enum TournamentStatus: WireNamedKind {
    case registration
    case inProgress
    case completed
    case cancelled
    case unknown(String)

    static let known: [TournamentStatus] = [.registration, .inProgress, .completed, .cancelled]

    private static let registrationName = "registration"
    private static let inProgressName = "in_progress"
    private static let completedName = "completed"
    private static let cancelledName = "cancelled"

    var wireName: String {
        switch self {
        case .registration: Self.registrationName
        case .inProgress: Self.inProgressName
        case .completed: Self.completedName
        case .cancelled: Self.cancelledName
        case .unknown(let name): name
        }
    }

    var displayName: String {
        switch self {
        case .registration: AppBranding.Tournaments.registrationStatus
        case .inProgress: AppBranding.Tournaments.inProgressStatus
        case .completed: AppBranding.Tournaments.completedStatus
        case .cancelled: AppBranding.Tournaments.cancelledStatus
        case .unknown(let name): name
        }
    }

    /// Nothing more happens to a completed or cancelled tournament.
    var isOver: Bool { self == .completed || self == .cancelled }
}

/// An entry's standing: `withdrawn` is kept for an entry taken out after the start, which the bracket must still name.
/// A status a newer backend sends is kept by name and counts as not registered.
nonisolated enum EntryStatus: WireNamedKind {
    case registered
    case withdrawn
    case unknown(String)

    static let known: [EntryStatus] = [.registered, .withdrawn]

    private static let registeredName = "registered"
    private static let withdrawnName = "withdrawn"

    var wireName: String {
        switch self {
        case .registered: Self.registeredName
        case .withdrawn: Self.withdrawnName
        case .unknown(let name): name
        }
    }
}

/// Where a match stands: waiting for its sides or a result, given a time and place, a score one side reported, a
/// score both sides (or the organiser) stand behind, a no-show the organiser recorded, or a first-round bye. A status a
/// newer backend sends is kept by name: the match is neither decided nor open, so nothing is offered for it.
nonisolated enum MatchStatus: WireNamedKind {
    case pending
    case scheduled
    case reported
    case confirmed
    case walkover
    case bye
    case unknown(String)

    static let known: [MatchStatus] = [.pending, .scheduled, .reported, .confirmed, .walkover, .bye]

    private static let pendingName = "pending"
    private static let scheduledName = "scheduled"
    private static let reportedName = "reported"
    private static let confirmedName = "confirmed"
    private static let walkoverName = "walkover"
    private static let byeName = "bye"

    var wireName: String {
        switch self {
        case .pending: Self.pendingName
        case .scheduled: Self.scheduledName
        case .reported: Self.reportedName
        case .confirmed: Self.confirmedName
        case .walkover: Self.walkoverName
        case .bye: Self.byeName
        case .unknown(let name): name
        }
    }

    /// A result nobody can change but the organiser.
    var isDecided: Bool { self == .confirmed || self == .walkover || self == .bye }
    /// Waiting for a result, with or without a time.
    var isOpen: Bool { self == .pending || self == .scheduled }
}

/// Which side of the next match a winner advances into. A slot a newer backend sends is kept by name and places
/// nobody: the next match's sides are the backend's to fill.
nonisolated enum MatchSlot: WireNamedKind {
    case a
    case b
    case unknown(String)

    static let known: [MatchSlot] = [.a, .b]

    private static let aName = "a"
    private static let bName = "b"

    var wireName: String {
        switch self {
        case .a: Self.aName
        case .b: Self.bName
        case .unknown(let name): name
        }
    }
}
