import Foundation
@testable import lily

/// The fake's results: a report, a confirm, a dispute and a walkover change the match as the backend would, and a decided
/// match settles through `TournamentDetail.settling` (winner advanced, tournament completed). A scripted `lostAnswerError`
/// is thrown after the result was stored, as a commit whose answer never arrived. Split out to keep the class body under
/// SwiftLint's limit.
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
        return try answer(scored, in: detail)
    }

    func confirm(id: String, matchID: String) async throws -> TournamentDetail {
        confirmedMatchIDs.append(matchID)
        try throwIfScripted()
        let (detail, match) = try storedMatch(id, matchID)
        return try answer(match.confirming(by: TestFixtures.user.id, at: .now), in: detail)
    }

    func dispute(id: String, matchID: String) async throws -> TournamentDetail {
        disputedMatchIDs.append(matchID)
        try throwIfScripted()
        let (detail, match) = try storedMatch(id, matchID)
        return try answer(match.disputing(), in: detail)
    }

    func walkover(id: String, matchID: String, winnerEntryID: String) async throws -> TournamentDetail {
        walkovers.append((matchID, winnerEntryID))
        try throwIfScripted()
        let (detail, match) = try storedMatch(id, matchID)
        return try answer(match.walkover(winnerEntryId: winnerEntryID, by: TestFixtures.user.id, at: .now), in: detail)
    }

    private func storedMatch(_ id: String, _ matchID: String) throws -> (TournamentDetail, TournamentMatch) {
        let detail = try stored(id)
        guard let match = detail.match(id: matchID) else { throw AppError.matchNotFound }
        return (detail, match)
    }

    /// Stores the settled result, then answers it unless the answer is scripted lost.
    private func answer(_ match: TournamentMatch, in detail: TournamentDetail) throws -> TournamentDetail {
        let stored = store(detail.settling(match, at: .now))
        try throwLostAnswer()
        return stored
    }
}
