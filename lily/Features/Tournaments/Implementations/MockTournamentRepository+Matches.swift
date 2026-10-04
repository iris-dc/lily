import Foundation

/// The start and the results: the backend's match rules in memory, its refusals in its order. A start draws the matches
/// through `TournamentSchedule`; every match route needs the tournament under way (`MATCH_NOT_READY` whoever asks) and
/// a match the id names (`MATCH_NOT_FOUND`), then asks who the caller is (`NOT_IN_MATCH`) before what the match can
/// take. A side's score is `reported` until the other side confirms it or reports the same score; the organiser's is
/// `confirmed` at once; a report is answered by the other side or the organiser, never by the side that made it, which
/// reports again instead; a settled result advances the winner in a bracket and completes the tournament on the final,
/// or on a round robin's last open match with the table's leader as winner; a round robin's standings are recomputed on
/// every write.
extension MockTournamentRepository {
    func start(id: String) async throws -> TournamentDetail {
        let detail = try organized(id)
        let tournament = detail.tournament
        if tournament.status == .inProgress { return resolved(detail) }
        guard tournament.status == .registration else { throw AppError.tournamentLocked }
        guard tournament.canStart else { throw AppError.notEnoughEntries }
        let seeds = detail.registeredEntries.sorted { $0.seed < $1.seed }.map(\.id)
        let matches = TournamentSchedule.pairings(format: tournament.format, seeds: seeds).map {
            TournamentMatch(pairing: $0, tournamentId: id)
        }
        let started = detail.replacing(tournament: tournament.starting(at: now()))
        logger.info(.tournaments, "Mock tournament \(id) started with \(seeds.count) entries")
        return resolved(storeMatches(matches, in: started))
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
        return resolved(settle(match.confirming(by: MockTournamentFixtures.callerMarker, at: now()), in: detail))
    }

    func dispute(id: String, matchID: String) async throws -> TournamentDetail {
        let (detail, match) = try runningMatch(id, matchID)
        try requireAnswerable(match, in: detail)
        logger.info(.tournaments, "Mock dispute of match \(matchID) of \(id)")
        return resolved(replace(match.disputing(), in: detail))
    }

    func walkover(id: String, matchID: String, winnerEntryID: String) async throws -> TournamentDetail {
        let (detail, match) = try runningMatch(id, matchID)
        try requireOrganizer(of: detail)
        try requireOpen(match)
        guard match.contains(entryID: winnerEntryID) else { throw AppError.tournamentActionFailed }
        let settled = match.walkover(winnerEntryId: winnerEntryID, by: MockTournamentFixtures.callerMarker, at: now())
        return resolved(settle(settled, in: detail))
    }

    func schedule(id: String, matchID: String, _ schedule: MatchSchedule) async throws -> TournamentMatch {
        let (detail, match) = try runningMatch(id, matchID)
        try requireOrganizer(of: detail)
        guard !match.isDecided else { throw AppError.matchNotReady }
        let scheduled = match.scheduling(schedule)
        replace(scheduled, in: detail)
        return scheduled
    }

    /// A match of a tournament under way, under the read rule: not in progress refuses whoever asks, and a well-formed
    /// id that names no match is its own refusal, in that order.
    private func runningMatch(_ id: String, _ matchID: String) throws -> (TournamentDetail, TournamentMatch) {
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

    /// A settled result: the winner stands in the next match of a bracket; the final's result, or a round robin's last,
    /// completes the tournament.
    private func settle(_ match: TournamentMatch, in detail: TournamentDetail) -> TournamentDetail {
        var detail = replace(match, in: detail)
        guard match.isDecided else { return detail }
        if let nextID = match.nextMatchId, let slot = match.nextSlot, let winner = match.winnerEntryId,
           let next = detail.match(id: nextID) {
            detail = replace(next.placing(winner, in: slot), in: detail)
        } else if let champion = champion(of: detail) {
            detail = store(detail.replacing(tournament: detail.tournament.completing(winnerEntryId: champion, at: now())))
            logger.info(.tournaments, "Mock tournament \(detail.id) completed")
        }
        return detail
    }

    /// The winner once nothing is left to play: the final's in a bracket, the table's leader in a round robin.
    private func champion(of detail: TournamentDetail) -> String? {
        guard detail.matches.allSatisfy(\.isDecided) else { return nil }
        switch detail.tournament.format {
        case .singleElimination: return detail.matches.first { $0.nextMatchId == nil }?.winnerEntryId
        case .roundRobin: return detail.standings.first?.entryId
        }
    }

    @discardableResult
    private func replace(_ match: TournamentMatch, in detail: TournamentDetail) -> TournamentDetail {
        var matches = detail.matches
        if let index = matches.firstIndex(where: { $0.id == match.id }) { matches[index] = match }
        return storeMatches(matches, in: detail)
    }

    private func storeMatches(_ matches: [TournamentMatch], in detail: TournamentDetail) -> TournamentDetail {
        let standings = detail.tournament.format == .roundRobin
            ? RoundRobinStandings.compute(entries: detail.registeredEntries, matches: matches)
            : []
        return store(detail.replacing(matches: matches, standings: standings))
    }
}
