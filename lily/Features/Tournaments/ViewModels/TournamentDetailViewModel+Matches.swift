import Foundation

/// The start and the results, from the detail. Every write answers the whole detail, which replaces the one on screen
/// and reaches the lists behind through `onChange`; who may do what with a match is `MatchActions`, decided from the
/// loaded detail and the caller, so the sheet and the cells never guess.
extension TournamentDetailViewModel {
    /// Start is offered to the organiser while registration is open, and enabled once enough entries are in.
    var showsStart: Bool { role.isOrganizer && tournament?.status == .registration }
    var canStart: Bool { tournament?.canStart ?? false }
    /// Why Start is disabled, for the menu item's subtitle; `nil` while it is enabled.
    var startBlockedReason: String? {
        guard let tournament, showsStart, !tournament.canStart else { return nil }
        return AppBranding.Tournaments.startNeeds(tournament.format.minimumEntriesToStart, teamSize: tournament.teamSize)
    }
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
        await write("Report result") { [self] in
            let answer = try await repository.report(id: destination.id, matchID: match.id, scoreA: scoreA, scoreB: scoreB)
            logMatch(match.id, "result \(answer.match(id: match.id)?.status.rawValue ?? "unknown")")
            return answer
        }
    }

    @discardableResult
    func confirm(_ match: TournamentMatch) async -> Bool {
        await write("Confirm result") { [self] in
            let answer = try await repository.confirm(id: destination.id, matchID: match.id)
            logMatch(match.id, "result confirmed")
            return answer
        }
    }

    @discardableResult
    func dispute(_ match: TournamentMatch) async -> Bool {
        await write("Dispute result") { [self] in
            let answer = try await repository.dispute(id: destination.id, matchID: match.id)
            logMatch(match.id, "result disputed")
            return answer
        }
    }

    @discardableResult
    func walkover(_ match: TournamentMatch, winnerEntryID: String) async -> Bool {
        await write("Walkover") { [self] in
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
            let updated = try await repository.schedule(id: destination.id, matchID: match.id, schedule)
            guard let current = detail else { return }
            accept(current.replacing(match: updated))
            logMatch(match.id, schedule.scheduledAt == nil && schedule.location == nil ? "schedule cleared" : "scheduled")
        }
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
