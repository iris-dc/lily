import Foundation

/// What a chat row is: something a member wrote, or a system note the backend posted (a game created in the group;
/// in a tournament's room its start, a result, a dispute and the winner). A kind this build does not know keeps its
/// name and counts as a system note that `ChatTimeline` leaves out, so a room from a newer backend still decodes and
/// shows nothing for it rather than a wrong line.
nonisolated enum MessageKind: WireNamedKind {
    case text
    case eventCreated
    case tournamentStarted
    case matchResult
    case matchDisputed
    case tournamentCompleted
    case unknown(String)

    private static let textName = "text"
    private static let eventCreatedName = "event_created"
    private static let tournamentStartedName = "tournament_started"
    private static let matchResultName = "match_result"
    private static let matchDisputedName = "match_disputed"
    private static let tournamentCompletedName = "tournament_completed"

    init(wireName: String) {
        switch wireName {
        case Self.textName: self = .text
        case Self.eventCreatedName: self = .eventCreated
        case Self.tournamentStartedName: self = .tournamentStarted
        case Self.matchResultName: self = .matchResult
        case Self.matchDisputedName: self = .matchDisputed
        case Self.tournamentCompletedName: self = .tournamentCompleted
        default: self = .unknown(wireName)
        }
    }

    var wireName: String {
        switch self {
        case .text: Self.textName
        case .eventCreated: Self.eventCreatedName
        case .tournamentStarted: Self.tournamentStartedName
        case .matchResult: Self.matchResultName
        case .matchDisputed: Self.matchDisputedName
        case .tournamentCompleted: Self.tournamentCompletedName
        case .unknown(let name): name
        }
    }

    /// A note about a tournament: it carries `tournamentId` and opens the tournament.
    var isTournamentNote: Bool {
        switch self {
        case .tournamentStarted, .matchResult, .matchDisputed, .tournamentCompleted: true
        case .text, .eventCreated, .unknown: false
        }
    }

    var isUnknown: Bool {
        if case .unknown = self { return true }
        return false
    }
}
