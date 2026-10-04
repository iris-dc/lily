import Foundation

/// What the caller may do with one match, decided in one place from the tournament's state, the match's status and
/// who the caller is, so the sheet, the cells and the tests agree. Nothing is offered before the start or after the
/// end, to guests, outsiders or an entrant whose match it is not. The organiser records (confirmed at once), gives a
/// walkover, confirms a reported score and sets the time and place of any match not yet decided (a later round's
/// before its sides are known); a side reports until the other side has reported, then confirms or disputes.
nonisolated struct MatchActions: Equatable, Sendable {
    let canReport: Bool
    let canConfirm: Bool
    let canDispute: Bool
    let canRecord: Bool
    let canWalkover: Bool
    let canSchedule: Bool
    /// The caller's side reported and the other side has not answered yet: a caption, no action.
    let awaitsOtherSide: Bool

    static let none = MatchActions(canReport: false,
                                   canConfirm: false,
                                   canDispute: false,
                                   canRecord: false,
                                   canWalkover: false,
                                   canSchedule: false,
                                   awaitsOtherSide: false)

    var isEmpty: Bool { self == .none }
    /// Whether the sheet shows score fields: a report or a record is on offer.
    var takesScore: Bool { canReport || canRecord }
}

/// The rule itself; in an extension so the memberwise init above stays synthesized.
nonisolated extension MatchActions {
    init(detail: TournamentDetail, match: TournamentMatch, userID: String?) {
        guard detail.tournament.status == .inProgress, let userID else {
            self = .none
            return
        }
        switch TournamentRole(tournament: detail.tournament, userID: userID) {
        case .organizer:
            self = .organizer(match)
        case .entrant(let entryID):
            guard match.contains(entryID: entryID), let entry = detail.entry(id: entryID) else {
                self = .none
                return
            }
            self = .side(match, entry: entry)
        case .guest, .outsider:
            self = .none
        }
    }

    /// The organiser's word is final: a record confirms at once, a reported score is confirmed with one tap; the time
    /// and place may be set until the match is decided (the backend refuses a schedule on a confirmed match alone).
    private static func organizer(_ match: TournamentMatch) -> MatchActions {
        MatchActions(canReport: false,
                     canConfirm: match.status == .reported,
                     canDispute: false,
                     canRecord: match.isReadyForResult,
                     canWalkover: match.isReadyForResult,
                     canSchedule: !match.isDecided,
                     awaitsOtherSide: false)
    }

    /// A side reports until the other side has reported; then it confirms or disputes that report, and a report of
    /// its own waits for the other side.
    private static func side(_ match: TournamentMatch, entry: TournamentEntry) -> MatchActions {
        let reportedByMySide = match.reportedBy.map { entry.contains(userID: $0) } ?? false
        let otherSideReported = match.status == .reported && !reportedByMySide
        return MatchActions(canReport: match.isReadyForResult && !otherSideReported,
                            canConfirm: otherSideReported,
                            canDispute: otherSideReported,
                            canRecord: false,
                            canWalkover: false,
                            canSchedule: false,
                            awaitsOtherSide: match.status == .reported && reportedByMySide)
    }
}
