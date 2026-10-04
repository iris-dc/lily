import Foundation

/// The start and the results: the backend's match rules in memory. A start draws the matches through
/// `TournamentSchedule`; a result from a side is `reported` until the other side confirms (or reports the same score),
/// the organiser's is `confirmed` at once; a confirmed result advances the winner in single elimination and completes
/// the tournament on the final; a round robin's standings are recomputed on every write.
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
        let (detail, match) = try openMatch(id, matchID)
        guard AppConfig.Tournaments.scoreRange.contains(scoreA), AppConfig.Tournaments.scoreRange.contains(scoreB) else {
            throw AppError.tournamentActionFailed
        }
        guard scoreA != scoreB || detail.tournament.allowsDraws else { throw AppError.drawNotAllowed }
        let caller = MockTournamentFixtures.callerMarker
        let isOrganizer = detail.tournament.organizerUserId == caller
        guard isOrganizer || isSide(of: match, in: detail) else { throw AppError.notInMatch }
        let agrees = match.status == .reported && match.scoreA == scoreA && match.scoreB == scoreB && match.reportedBy != caller
        let scored = match.scored(scoreA, scoreB, by: caller, confirmed: isOrganizer || agrees, at: now())
        logger.info(.tournaments, "Mock result for match \(matchID) of \(id): \(scored.status.rawValue)")
        return resolved(settle(scored, in: detail))
    }

    func confirm(id: String, matchID: String) async throws -> TournamentDetail {
        let (detail, match) = try openMatch(id, matchID)
        let caller = MockTournamentFixtures.callerMarker
        guard match.status == .reported, match.reportedBy != caller else { throw AppError.matchNotReady }
        guard detail.tournament.organizerUserId == caller || isSide(of: match, in: detail) else { throw AppError.notInMatch }
        return resolved(settle(match.confirming(by: caller, at: now()), in: detail))
    }

    func dispute(id: String, matchID: String) async throws -> TournamentDetail {
        let (detail, match) = try openMatch(id, matchID)
        guard match.status == .reported else { throw AppError.matchNotReady }
        guard detail.tournament.organizerUserId == MockTournamentFixtures.callerMarker || isSide(of: match, in: detail) else {
            throw AppError.notInMatch
        }
        return resolved(replace(match.disputing(), in: detail))
    }

    func walkover(id: String, matchID: String, winnerEntryID: String) async throws -> TournamentDetail {
        let detail = try organized(id)
        let (_, match) = try openMatch(id, matchID)
        guard match.contains(entryID: winnerEntryID) else { throw AppError.tournamentActionFailed }
        let settled = match.walkover(winnerEntryId: winnerEntryID, by: MockTournamentFixtures.callerMarker, at: now())
        return resolved(settle(settled, in: detail))
    }

    func schedule(id: String, matchID: String, _ schedule: MatchSchedule) async throws -> TournamentMatch {
        let detail = try organized(id)
        guard let match = detail.match(id: matchID) else { throw AppError.matchNotReady }
        guard !match.isDecided else { throw AppError.matchNotReady }
        let scheduled = match.scheduling(schedule)
        replace(scheduled, in: detail)
        return scheduled
    }

    /// A match that may still take a result, in a tournament under way.
    private func openMatch(_ id: String, _ matchID: String) throws -> (TournamentDetail, TournamentMatch) {
        let detail = try readable(id)
        guard detail.tournament.status == .inProgress, let match = detail.match(id: matchID), match.isReadyForResult else {
            throw AppError.matchNotReady
        }
        return (detail, match)
    }

    private func isSide(of match: TournamentMatch, in detail: TournamentDetail) -> Bool {
        match.contains(entryID: detail.entry(containing: MockTournamentFixtures.callerMarker)?.id)
    }

    /// A confirmed result: the winner advances in a bracket, the final completes the tournament.
    private func settle(_ match: TournamentMatch, in detail: TournamentDetail) -> TournamentDetail {
        var detail = replace(match, in: detail)
        guard match.isDecided, let winner = match.winnerEntryId else { return detail }
        if let nextID = match.nextMatchId, let slot = match.nextSlot, let next = detail.match(id: nextID) {
            detail = replace(next.placing(winner, in: slot), in: detail)
        } else if detail.tournament.format == .singleElimination {
            detail = store(detail.replacing(tournament: detail.tournament.completing(winnerEntryId: winner, at: now())))
            logger.info(.tournaments, "Mock tournament \(detail.id) completed")
        }
        return detail
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
