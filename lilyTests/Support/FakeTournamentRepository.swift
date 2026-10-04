import Foundation
@testable import lily

/// Scriptable `TournamentRepository`: lists answer from `result`, the detail from `details`, writes change the stored
/// detail the way the backend would (the results in `FakeTournamentRepository+Matches.swift`), and every call is recorded.
@MainActor
final class FakeTournamentRepository: TournamentRepository {
    var result: Result<[Tournament], AppError> = .success([])
    /// The details `tournament(id:)` answers, by id; a miss is `.tournamentNotFound`.
    var details: [String: TournamentDetail] = [:]
    /// Thrown instead of any answer when set, for errors that are not `AppError` (such as `CancellationError`).
    var thrownError: (any Error)?
    /// Thrown by every write when set.
    var actionError: (any Error)?
    /// Thrown by the next writes, one each, before `actionError` is consulted: a `.tryAgain` that a repeat gets past.
    var transientErrors: [AppError] = []
    /// Thrown by `tournament(id:)` when set (a refetch that fails).
    var detailError: (any Error)?
    /// While true, list and detail requests record the call and then suspend until `releaseRequests()`.
    var holdsRequests: Bool {
        get { hold.isEnabled }
        set { hold.isEnabled = newValue }
    }
    var organizerUserID = "host"
    private let hold = RequestHold()
    private var entrySequence = 10
    private(set) var requestedScopes: [TournamentScope] = []
    private(set) var requestedPositions: [Coordinate?] = []
    private(set) var fetchedIDs: [String] = []
    private(set) var createdDrafts: [TournamentDraft] = []
    private(set) var updatedDrafts: [(id: String, draft: TournamentDraft)] = []
    private(set) var joins: [(id: String, teamName: String?)] = []
    private(set) var teamJoins: [(id: String, entryID: String)] = []
    private(set) var leaves: [Leave] = []

    struct Leave: Equatable {
        let id: String
        let entryID: String
        let userID: String
    }
    private(set) var removedEntries: [(id: String, entryID: String)] = []
    private(set) var cancelledIDs: [String] = []
    private(set) var startedIDs: [String] = []
    private(set) var schedules: [(matchID: String, schedule: MatchSchedule)] = []
    /// The results, recorded by the `+Matches` file, hence not `private(set)`.
    var reports: [Report] = []
    var confirmedMatchIDs: [String] = []
    var disputedMatchIDs: [String] = []
    var walkovers: [(matchID: String, winnerEntryID: String)] = []

    struct Report: Equatable {
        let matchID: String
        let scoreA: Int
        let scoreB: Int
    }

    func tournaments(in scope: TournamentScope, near position: Coordinate?) async throws -> [Tournament] {
        requestedScopes.append(scope)
        requestedPositions.append(position)
        await hold.wait()
        if let thrownError { throw thrownError }
        return try result.get()
    }

    func tournament(id: String) async throws -> TournamentDetail {
        fetchedIDs.append(id)
        await hold.wait()
        if let thrownError { throw thrownError }
        if let detailError { throw detailError }
        guard let detail = details[id] else { throw AppError.tournamentNotFound }
        return detail
    }

    func create(_ draft: TournamentDraft) async throws -> TournamentDetail {
        createdDrafts.append(draft)
        await hold.wait()
        try throwIfScripted()
        let tournament = draft.makeTournament(organizerUserId: organizerUserID,
                                              organizerName: TestFixtures.user.displayName,
                                              coordinate: draft.coordinate ?? AppConfig.Location.mockCenter,
                                              now: .now)
        let detail = TournamentDetail(tournament: tournament)
        details[tournament.id] = detail
        return detail
    }

    func update(id: String, _ draft: TournamentDraft) async throws -> TournamentDetail {
        updatedDrafts.append((id, draft))
        try throwIfScripted()
        let detail = try stored(id)
        return store(detail.replacing(tournament: detail.tournament.updating(with: draft, at: .now)))
    }

    /// The caller (`TestFixtures.user`) enters: alone, or as the captain of a team named `teamName`.
    func join(id: String, teamName: String?) async throws -> TournamentEntry {
        joins.append((id, teamName))
        try throwIfScripted()
        let detail = try stored(id)
        entrySequence += 1
        let entry = TournamentEntry(id: "01J9ENTRY000000000000000\(entrySequence)",
                                    tournamentId: id,
                                    name: teamName ?? TestFixtures.user.displayName,
                                    captainUserId: TestFixtures.user.id,
                                    members: [callerMember],
                                    seed: detail.entries.count + 1,
                                    createdAt: .now)
        let tournament = detail.tournament.updatingEntries(count: detail.tournament.entryCount + 1, myEntryId: entry.id, at: .now)
        store(detail.replacing(entries: detail.entries + [entry]).replacing(tournament: tournament))
        return entry
    }

    func joinTeam(id: String, entryID: String) async throws -> TournamentEntry {
        teamJoins.append((id, entryID))
        try throwIfScripted()
        let detail = try stored(id)
        guard let index = detail.entries.firstIndex(where: { $0.id == entryID }) else { throw AppError.entryNotFound }
        var entries = detail.entries
        entries[index] = entries[index].adding(callerMember)
        let tournament = detail.tournament.updatingEntries(count: detail.tournament.entryCount, myEntryId: entryID, at: .now)
        store(detail.replacing(entries: entries).replacing(tournament: tournament))
        return entries[index]
    }

    func leave(id: String, entryID: String, userID: String) async throws -> TournamentEntry? {
        leaves.append(Leave(id: id, entryID: entryID, userID: userID))
        try throwIfScripted()
        let detail = try stored(id)
        guard let index = detail.entries.firstIndex(where: { $0.id == entryID }) else { throw AppError.entryNotFound }
        var entries = detail.entries
        let remaining = entries[index].removing(userID: userID)
        if let remaining { entries[index] = remaining } else { entries.remove(at: index) }
        let tournament = detail.tournament.updatingEntries(count: entries.count, myEntryId: nil, at: .now)
        store(detail.replacing(entries: entries).replacing(tournament: tournament))
        return remaining
    }

    func removeEntry(id: String, entryID: String) async throws {
        removedEntries.append((id, entryID))
        try throwIfScripted()
        let detail = try stored(id)
        let entries = detail.entries.filter { $0.id != entryID }
        store(detail.replacing(entries: entries)
            .replacing(tournament: detail.tournament.updatingEntries(count: entries.count, myEntryId: nil, at: .now)))
    }

    /// Draws the matches like the backend, through the shared pairings.
    func start(id: String) async throws -> TournamentDetail {
        startedIDs.append(id)
        try throwIfScripted()
        let detail = try stored(id)
        let seeds = detail.registeredEntries.sorted { $0.seed < $1.seed }.map(\.id)
        let matches = TournamentSchedule.pairings(format: detail.tournament.format, seeds: seeds).map {
            TournamentMatch(pairing: $0, tournamentId: id)
        }
        let standings = detail.tournament.format == .roundRobin
            ? RoundRobinStandings.compute(entries: detail.registeredEntries, matches: matches)
            : []
        let started = detail.replacing(tournament: detail.tournament.starting(at: .now))
        return store(started.replacing(matches: matches, standings: standings))
    }

    /// Answers the match alone, as the backend does; the stored detail follows so a refetch agrees.
    func schedule(id: String, matchID: String, _ schedule: MatchSchedule) async throws -> TournamentMatch {
        schedules.append((matchID, schedule))
        try throwIfScripted()
        let detail = try stored(id)
        guard let match = detail.match(id: matchID) else { throw AppError.matchNotFound }
        let scheduled = match.scheduling(schedule)
        store(detail.replacing(match: scheduled))
        return scheduled
    }

    func cancel(id: String) async throws -> TournamentDetail {
        cancelledIDs.append(id)
        try throwIfScripted()
        let detail = try stored(id)
        return store(detail.replacing(tournament: detail.tournament.cancelling(at: .now)))
    }

    /// Lets every held request through and stops holding new ones.
    func releaseRequests() {
        hold.release()
    }

    private var callerMember: EntryMember {
        EntryMember(userId: TestFixtures.user.id, displayName: TestFixtures.user.displayName)
    }

    /// Shared with the `+Matches` file, hence not `private`.
    func throwIfScripted() throws {
        if !transientErrors.isEmpty { throw transientErrors.removeFirst() }
        if let actionError { throw actionError }
    }

    func stored(_ id: String) throws -> TournamentDetail {
        guard let detail = details[id] else { throw AppError.tournamentNotFound }
        return detail
    }

    @discardableResult
    func store(_ detail: TournamentDetail) -> TournamentDetail {
        details[detail.id] = detail
        return detail
    }
}
