import Foundation

/// The start and the results: the backend's refusals in its order, in memory. A start is the organiser's while
/// registration is open and needs the format's minimum (a second start replays); every match route needs a signed-in
/// caller, the tournament under way (`MATCH_NOT_READY` whoever asks) and a match the id names (`MATCH_NOT_FOUND`), then
/// asks who the caller is (`NOT_IN_MATCH`) before what the match can take. A side's score is `reported` until the other
/// side confirms it or reports the same score; the organiser's is `confirmed` at once; a report is answered by the
/// other side or the organiser, never by the side that made it, which reports again instead. What a start draws and
/// what a settled result moves (the winner's advance, the table, the completion) is `TournamentDetail.starting` and
/// `.settling`'s.
extension MockTournamentRepository {
    func start(id: String) async throws -> TournamentDetail {
        let detail = try organized(id)
        let tournament = detail.tournament
        if tournament.status == .inProgress { return resolved(detail) }
        guard tournament.status == .registration else { throw AppError.tournamentLocked }
        guard tournament.canStart else { throw AppError.notEnoughEntries }
        logger.info(.tournaments, "Mock tournament \(id) started with \(detail.registeredEntries.count) entries")
        return resolved(store(detail.starting(at: now())))
    }

    func report(id: String, matchID: String, scoreA: Int, scoreB: Int) async throws -> TournamentDetail {
        let range = AppConfig.Tournaments.scoreRange
        guard range.contains(scoreA), range.contains(scoreB) else { throw AppError.tournamentActionFailed }
        let (detail, match) = try runningMatch(id, matchID)
        try requireSideOrOrganizer(match, in: detail)
        try requireOpen(match)
        guard scoreA != scoreB || detail.tournament.permitsDraws else { throw AppError.drawNotAllowed }
        let caller = MockTournamentFixtures.callerMarker
        let scored: TournamentMatch
        if isOrganizer(of: detail) {
            scored = match.recording(scoreA, scoreB, by: caller, at: now())
        } else if match.status == .reported, !reportedBySide(of: caller, match, in: detail),
                  match.scoreA == scoreA, match.scoreB == scoreB {
            scored = match.confirming(by: caller, at: now())
        } else {
            scored = match.reporting(scoreA, scoreB, by: caller, at: now())
        }
        logger.info(.tournaments, "Mock result for match \(matchID) of \(id): \(scored.status.rawValue)")
        return resolved(settle(scored, in: detail))
    }

    func confirm(id: String, matchID: String) async throws -> TournamentDetail {
        let (detail, match) = try runningMatch(id, matchID)
        try requireAnswerable(match, in: detail)
        logger.info(.tournaments, "Mock match \(matchID) of \(id) confirmed")
        return resolved(settle(match.confirming(by: MockTournamentFixtures.callerMarker, at: now()), in: detail))
    }

    func dispute(id: String, matchID: String) async throws -> TournamentDetail {
        let (detail, match) = try runningMatch(id, matchID)
        try requireAnswerable(match, in: detail)
        logger.info(.tournaments, "Mock dispute of match \(matchID) of \(id)")
        return resolved(settle(match.disputing(), in: detail))
    }

    func walkover(id: String, matchID: String, winnerEntryID: String) async throws -> TournamentDetail {
        let (detail, match) = try runningMatch(id, matchID)
        try requireOrganizer(of: detail)
        try requireOpen(match)
        guard match.contains(entryID: winnerEntryID) else { throw AppError.tournamentActionFailed }
        logger.info(.tournaments, "Mock walkover for match \(matchID) of \(id): entry \(winnerEntryID)")
        let settled = match.walkover(winnerEntryId: winnerEntryID, by: MockTournamentFixtures.callerMarker, at: now())
        return resolved(settle(settled, in: detail))
    }

    /// A schedule moves no result, so the match takes its place and the table stays.
    func schedule(id: String, matchID: String, _ schedule: MatchSchedule) async throws -> TournamentMatch {
        let (detail, match) = try runningMatch(id, matchID)
        try requireOrganizer(of: detail)
        guard !match.isDecided else { throw AppError.matchNotReady }
        let scheduled = match.scheduling(schedule)
        store(detail.replacing(match: scheduled))
        let outcome = schedule.isEmpty ? "schedule cleared" : "scheduled"
        logger.info(.tournaments, "Mock match \(matchID) of \(id) \(outcome)")
        return scheduled
    }

    /// A match of a tournament under way, for a signed-in caller under the read rule: not in progress refuses whoever
    /// asks, and a well-formed id that names no match is its own refusal, in that order.
    private func runningMatch(_ id: String, _ matchID: String) throws -> (TournamentDetail, TournamentMatch) {
        try requireCaller()
        let detail = try readable(id)
        guard detail.tournament.status == .inProgress else { throw AppError.matchNotReady }
        guard let match = detail.match(id: matchID) else { throw AppError.matchNotFound }
        return (detail, match)
    }

    private func isOrganizer(of detail: TournamentDetail) -> Bool {
        detail.tournament.organizerUserId == MockTournamentFixtures.callerMarker
    }

    private func requireOrganizer(of detail: TournamentDetail) throws {
        guard isOrganizer(of: detail) else { throw AppError.notOrganizer }
    }

    /// The organiser and the players of either side write a match; nobody else.
    private func requireSideOrOrganizer(_ match: TournamentMatch, in detail: TournamentDetail) throws {
        let mine = detail.entry(containing: MockTournamentFixtures.callerMarker)?.id
        guard isOrganizer(of: detail) || match.contains(entryID: mine) else { throw AppError.notInMatch }
    }

    /// A match that can take a result: both sides known, nothing final.
    private func requireOpen(_ match: TournamentMatch) throws {
        guard match.isReadyForResult else { throw AppError.matchNotReady }
    }

    /// A report is answered by the other side or the organiser; the side that made it reports again instead.
    private func requireAnswerable(_ match: TournamentMatch, in detail: TournamentDetail) throws {
        try requireSideOrOrganizer(match, in: detail)
        guard match.status == .reported else { throw AppError.matchNotReady }
        guard isOrganizer(of: detail) || !reportedBySide(of: MockTournamentFixtures.callerMarker, match, in: detail) else {
            throw AppError.matchNotReady
        }
    }

    /// Whether the stored report came from the user's side; a teammate's report counts as theirs.
    private func reportedBySide(of userID: String, _ match: TournamentMatch, in detail: TournamentDetail) -> Bool {
        guard let reporter = match.reportedBy, let side = detail.entry(containing: reporter) else { return false }
        return side.id == detail.entry(containing: userID)?.id
    }

    /// The result stored as `TournamentDetail.settling` makes it; the completion it may bring is logged here.
    private func settle(_ match: TournamentMatch, in detail: TournamentDetail) -> TournamentDetail {
        let settled = store(detail.settling(match, at: now()))
        if detail.tournament.status != .completed, settled.tournament.status == .completed {
            logger.info(.tournaments, "Mock tournament \(detail.id) completed")
        }
        return settled
    }
}
