import Foundation
@testable import lily

/// The results of the fake: a score is confirmed at once when `TestFixtures.user` organises (`organizerUserID`), reported
/// otherwise; a confirm, a dispute and a walkover change the match as the backend would; a decided match advances its
/// winner and completes the tournament, for both formats, as `TournamentDetail.settling` makes it. In a file of its own
/// so the class body stays under the limit.
extension FakeTournamentRepository {
    /// The organiser's (`organizerUserID`) score is confirmed at once, a side's is reported.
    func report(id: String, matchID: String, scoreA: Int, scoreB: Int) async throws -> TournamentDetail {
        reports.append(Report(matchID: matchID, scoreA: scoreA, scoreB: scoreB))
        try throwIfScripted()
        let (detail, match) = try storedMatch(id, matchID)
        let isOrganizer = detail.tournament.organizerUserId == TestFixtures.user.id
        let scored = isOrganizer
            ? match.recording(scoreA, scoreB, by: TestFixtures.user.id, at: .now)
            : match.reporting(scoreA, scoreB, by: TestFixtures.user.id, at: .now)
        return replace(scored, in: detail)
    }

    func confirm(id: String, matchID: String) async throws -> TournamentDetail {
        confirmedMatchIDs.append(matchID)
        try throwIfScripted()
        let (detail, match) = try storedMatch(id, matchID)
        return replace(match.confirming(by: TestFixtures.user.id, at: .now), in: detail)
    }

    func dispute(id: String, matchID: String) async throws -> TournamentDetail {
        disputedMatchIDs.append(matchID)
        try throwIfScripted()
        let (detail, match) = try storedMatch(id, matchID)
        return replace(match.disputing(), in: detail)
    }

    func walkover(id: String, matchID: String, winnerEntryID: String) async throws -> TournamentDetail {
        walkovers.append((matchID, winnerEntryID))
        try throwIfScripted()
        let (detail, match) = try storedMatch(id, matchID)
        return replace(match.walkover(winnerEntryId: winnerEntryID, by: TestFixtures.user.id, at: .now), in: detail)
    }

    private func storedMatch(_ id: String, _ matchID: String) throws -> (TournamentDetail, TournamentMatch) {
        let detail = try stored(id)
        guard let match = detail.match(id: matchID) else { throw AppError.matchNotFound }
        return (detail, match)
    }

    /// The result stored as `TournamentDetail.settling` makes it.
    private func replace(_ match: TournamentMatch, in detail: TournamentDetail) -> TournamentDetail {
        store(detail.settling(match, at: .now))
    }
}
