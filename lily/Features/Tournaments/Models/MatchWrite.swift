import Foundation

/// What a match write asked for, so that a write whose answer was lost can be read off the match fetched back: the
/// backend may have committed before the connection dropped, and a popup would send the user into a `MATCH_NOT_READY`
/// refusal for a result that already stands. The judgement is the backend's own repeat rule (a confirmed result,
/// confirmation or walkover by the caller's hand), widened for a side's report that stands or that the other side
/// confirmed meanwhile.
nonisolated enum MatchWrite: Hashable, Sendable {
    case result(scoreA: Int, scoreB: Int)
    case confirmation
    case dispute
    case walkover(winnerEntryID: String)
    case schedule(MatchSchedule)

    /// Whether `match`, fetched after the write's answer was lost, shows the write as done by `callerID`.
    func landed(on match: TournamentMatch, callerID: String) -> Bool {
        switch self {
        case let .result(scoreA, scoreB):
            return Self.resultStands(scoreA, scoreB, on: match, callerID: callerID)
        case .confirmation:
            return match.status == .confirmed && match.confirmedBy == callerID
        case .dispute:
            return match.isOpenDispute
        case let .walkover(winnerEntryID):
            return match.status == .walkover && match.winnerEntryId == winnerEntryID && match.confirmedBy == callerID
        case let .schedule(schedule):
            return match.scheduledAt == schedule.scheduledAt && match.location == schedule.location
        }
    }

    /// A dispute or a walkover drops the scores, so the asked-for scores still standing mean the result holds, as the
    /// caller's report or record, or as the caller's report the other side confirmed meanwhile.
    private static func resultStands(_ scoreA: Int, _ scoreB: Int, on match: TournamentMatch, callerID: String) -> Bool {
        match.scoreA == scoreA && match.scoreB == scoreB
            && (match.reportedBy == callerID || match.confirmedBy == callerID)
    }
}
