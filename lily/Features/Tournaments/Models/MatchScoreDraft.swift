import Foundation

/// The two typed scores of the match sheet and what keeps Report or Record disabled: both must parse within
/// `AppConfig.Tournaments.scoreRange`, and a tied score passes only where the tournament permits draws.
nonisolated struct MatchScoreDraft: Equatable, Sendable {
    var scoreA: String
    var scoreB: String

    /// A reported score is the starting point for the organiser's record or a side's correction; a pending match or no
    /// match opens empty.
    init(match: TournamentMatch?) {
        scoreA = match?.scoreA.map(String.init) ?? ""
        scoreB = match?.scoreB.map(String.init) ?? ""
    }

    /// Both scores as numbers within the range, `nil` while either is blank, not a number or out of range.
    var parsed: (a: Int, b: Int)? {
        let range = AppConfig.Tournaments.scoreRange
        guard let a = Int(scoreA), let b = Int(scoreB), range.contains(a), range.contains(b) else { return nil }
        return (a, b)
    }

    /// A tied score where the tournament allows none; an unparsed pair is no draw.
    func isDisallowedDraw(permitsDraws: Bool) -> Bool {
        guard let scores = parsed else { return false }
        return scores.a == scores.b && !permitsDraws
    }

    func canSubmit(permitsDraws: Bool) -> Bool {
        parsed != nil && !isDisallowedDraw(permitsDraws: permitsDraws)
    }
}
