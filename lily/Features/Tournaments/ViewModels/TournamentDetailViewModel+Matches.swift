import Foundation

/// The start and the results, from the detail. Every write answers the whole detail, which replaces the one on screen
/// and reaches the lists behind through `onChange`; a match write whose answer was lost is read back before it is
/// reported. Who may do what is `TournamentPermissions` (Start) and `MatchActions` (a match), decided from the loaded
/// detail and the caller, so the menu, the sheet and the cells never guess.
extension TournamentDetailViewModel {
    /// The bracket or the standings and the matches draw once the tournament started.
    var hasMatches: Bool { !(detail?.matches.isEmpty ?? true) }

    func actions(for match: TournamentMatch) -> MatchActions {
        guard let detail else { return .none }
        return MatchActions(detail: detail, match: match, userID: identity.currentUserID)
    }

    /// Whether the caller's entry is one side of the match.
    func isMine(_ match: TournamentMatch) -> Bool {
        match.contains(entryID: tournament?.myEntryId)
    }

    func entry(_ entryID: String?) -> TournamentEntry? {
        entryID.flatMap { detail?.entry(id: $0) }
    }

    /// The name on a cell; a side no feeder match has decided yet reads "TBD".
    func entryName(_ entryID: String?) -> String {
        entry(entryID)?.name ?? AppBranding.Tournaments.toBeDecided
    }

    /// The organiser draws the matches; registration closes with it.
    func start() async {
        await write("Start") { [self] in
            let started = try await repository.start(id: destination.id)
            logger.info(.tournaments, "Tournament \(destination.id) started with \(started.matches.count) matches")
            return started
        }
    }

    /// A side's score (`reported` until the other side agrees) or the organiser's (`confirmed` at once).
    @discardableResult
    func report(_ match: TournamentMatch, scoreA: Int, scoreB: Int) async -> Bool {
        await writeMatch("Report result", match, asking: .result(scoreA: scoreA, scoreB: scoreB)) { [self] in
            let answer = try await repository.report(id: destination.id, matchID: match.id, scoreA: scoreA, scoreB: scoreB)
            logMatch(match.id, "result \(answer.match(id: match.id)?.status.rawValue ?? "unknown")")
            return answer
        }
    }

    @discardableResult
    func confirm(_ match: TournamentMatch) async -> Bool {
        await writeMatch("Confirm result", match, asking: .confirmation) { [self] in
            let answer = try await repository.confirm(id: destination.id, matchID: match.id)
            logMatch(match.id, "result confirmed")
            return answer
        }
    }

    @discardableResult
    func dispute(_ match: TournamentMatch) async -> Bool {
        await writeMatch("Dispute result", match, asking: .dispute) { [self] in
            let answer = try await repository.dispute(id: destination.id, matchID: match.id)
            logMatch(match.id, "result disputed")
            return answer
        }
    }

    @discardableResult
    func walkover(_ match: TournamentMatch, winnerEntryID: String) async -> Bool {
        await writeMatch("Walkover", match, asking: .walkover(winnerEntryID: winnerEntryID)) { [self] in
            let answer = try await repository.walkover(id: destination.id, matchID: match.id, winnerEntryID: winnerEntryID)
            logMatch(match.id, "walkover for entry \(winnerEntryID)")
            return answer
        }
    }

    /// The organiser's time and place for a match (`MatchActions.canSchedule`); the route answers the match alone, which
    /// takes its place in the detail. An empty schedule clears both.
    @discardableResult
    func schedule(_ match: TournamentMatch, _ schedule: MatchSchedule) async -> Bool {
        await perform("Schedule") { [self] in
            do {
                let updated = try await repository.schedule(id: destination.id, matchID: match.id, schedule)
                guard let current = detail else { return }
                accept(current.replacing(match: updated))
            } catch let error as AppError where error.leavesMatchOutcomeUnknown {
                guard let fresh = await readBack(after: error, match, asking: .schedule(schedule), action: "Schedule") else {
                    throw error
                }
                accept(fresh)
            }
            logMatch(match.id, schedule.isEmpty ? "schedule cleared" : "scheduled")
        }
    }

    /// `write` for a match: a lost answer is read off the match fetched back, and the fresh detail stands in for it when
    /// it shows the write; any other failure goes on as it is.
    private func writeMatch(_ action: String,
                            _ match: TournamentMatch,
                            asking asked: MatchWrite,
                            _ work: () async throws -> TournamentDetail) async -> Bool {
        await write(action) { [self] in
            do {
                return try await work()
            } catch let error as AppError where error.leavesMatchOutcomeUnknown {
                guard let fresh = await readBack(after: error, match, asking: asked, action: action) else { throw error }
                return fresh
            }
        }
    }

    /// The detail fetched after a match write's answer was lost: the write's answer when the match shows it as the
    /// caller's. When it does not, the fresh detail still replaces the stale one, so the screen and the lists agree
    /// with the backend before the popup, and `nil` sends the error on; a failed read leaves the screen as it was.
    private func readBack(after error: AppError,
                          _ match: TournamentMatch,
                          asking asked: MatchWrite,
                          action: String) async -> TournamentDetail? {
        guard let fresh = try? await repository.tournament(id: destination.id) else {
            logger.warning(.tournaments, "Could not read tournament \(destination.id) back after \(error) on match \(match.id)")
            return nil
        }
        guard let callerID = identity.currentUserID, let current = fresh.match(id: match.id),
              asked.landed(on: current, callerID: callerID) else {
            accept(fresh)
            return nil
        }
        logger.info(.tournaments,
                    "\(action) landed for match \(match.id) of tournament \(destination.id) despite \(error); nothing to report")
        return fresh
    }

    /// The write's answer replaces the detail; a completion is worth a line of its own.
    @discardableResult
    private func write(_ action: String, _ write: () async throws -> TournamentDetail) async -> Bool {
        await perform(action) { [self] in
            let wasOver = tournament?.status.isOver ?? false
            let fresh = try await write()
            accept(fresh)
            if fresh.tournament.status == .completed, !wasOver {
                logger.info(.tournaments, "Tournament \(fresh.id) completed")
            }
        }
    }

    private func logMatch(_ matchID: String, _ outcome: String) {
        logger.info(.tournaments, "Match \(matchID) of tournament \(destination.id): \(outcome)")
    }
}

private extension AppError {
    /// A lost connection, or the route's fallback for a 5xx: the backend may have committed before either, so the write
    /// is read back. A refusal never is; it is the backend's word that nothing changed.
    var leavesMatchOutcomeUnknown: Bool { self == .network || self == .tournamentActionFailed }
}
