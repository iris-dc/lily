import Foundation

/// Fixture tournaments with in-memory entries and matches, for previews, UI tests and `-mock-events` runs. The caller is
/// `MockTournamentFixtures.callerMarker` in every stored row and whoever `identity` names on the way out, so one set of
/// fixtures serves any mock sign-in. The rooms live in the group mock, which this one admits into and leaves.
final class MockTournamentRepository: TournamentRepository {
    /// Stored state is internal, not private, so the `+Entries` and `+Matches` files can reach it.
    var details: [String: TournamentDetail]
    var entrySequence = 0
    /// Private tournaments the caller was invited into: readable before they enter, as the backend's `invitedUserIds`
    /// makes them (`MockInboxRepository` notes the pending invites).
    private var invitedTournamentIDs: Set<String> = []
    let groups: MockGroupRepository
    let identity: any IdentityProvider
    let logger: any Logging
    let now: () -> Date

    init(groups: MockGroupRepository, identity: any IdentityProvider, logger: any Logging, now: @escaping () -> Date = { .now }) {
        details = Dictionary(uniqueKeysWithValues: MockTournamentFixtures.make(now: now()).map { ($0.id, $0) })
        self.groups = groups
        self.identity = identity
        self.logger = logger
        self.now = now
    }

    /// Explore's list comes nearest first around a position, like the backend's ranked answer, and by start without one.
    func tournaments(in scope: TournamentScope, near position: Coordinate?) async throws -> [Tournament] {
        logger.debug(.tournaments, "Mock tournaments served for scope \(scope)")
        let all = details.values.map(\.tournament)
        let moment = now()
        switch scope {
        case .upcoming:
            let listed = all.filter { $0.isListed && $0.startsAt >= moment }
            return Self.upcomingOrder(listed, near: position).map(resolved)
        case .mine:
            return all.filter(isInRoom).sorted(by: Self.mineOrder).map(resolved)
        case .group(let id):
            return all.filter { $0.group?.id == id && $0.status != .cancelled }.sorted { $0.startsAt < $1.startsAt }.map(resolved)
        }
    }

    private static func upcomingOrder(_ tournaments: [Tournament], near position: Coordinate?) -> [Tournament] {
        guard let position else { return tournaments.sorted { $0.startsAt < $1.startsAt } }
        return tournaments.sorted { lhs, rhs in
            let (left, right) = (lhs.location.coordinate.distance(to: position), rhs.location.coordinate.distance(to: position))
            return left == right ? lhs.startsAt < rhs.startsAt : left < right
        }
    }

    func tournament(id: String) async throws -> TournamentDetail {
        logger.debug(.tournaments, "Mock tournament \(id) served")
        return resolved(try readable(id))
    }

    /// Like the backend: the draft's client id is the tournament id, so a repeated create answers the same tournament;
    /// the room is registered with the caller as its owner.
    func create(_ draft: TournamentDraft) async throws -> TournamentDetail {
        if let existing = details[draft.clientId] {
            logger.info(.tournaments, "Mock create replayed for tournament \(existing.id)")
            return resolved(existing)
        }
        guard let coordinate = draft.coordinate, meetsFormatFloor(draft) else { throw AppError.tournamentCreationFailed }
        if let groupID = draft.group?.id {
            guard let group = groups.find(groupID), group.isPublic || group.isMember else { throw AppError.groupNotFound }
            guard GroupAccess(group: group, userID: identity.currentUserID).canCreateEvents(in: group) else {
                throw AppError.insufficientRole
            }
        }
        let tournament = draft.makeTournament(organizerUserId: MockTournamentFixtures.callerMarker,
                                              organizerName: AppBranding.Tournaments.Create.mockOrganizerName,
                                              coordinate: coordinate,
                                              now: now())
        let detail = TournamentDetail(tournament: tournament)
        details[tournament.id] = detail
        groups.registerRoom(for: tournament, memberCount: MockTournamentFixtures.playerCount(of: detail))
        logger.info(.tournaments, "Mock tournament \(tournament.id) created (\(tournament.entriesDescription))")
        return resolved(detail)
    }

    /// Like the backend: the organiser alone; once registration is over (started, completed or cancelled alike) only
    /// the name, description and place may differ from what is stored.
    func update(id: String, _ draft: TournamentDraft) async throws -> TournamentDetail {
        let detail = try organized(id)
        let tournament = detail.tournament
        if tournament.status != .registration {
            guard draft.startsAt == tournament.startsAt, draft.registrationClosesAt == tournament.registrationClosesAt,
                  draft.resolvedAllowsDraws == tournament.allowsDraws, draft.maxEntries == tournament.maxEntries else {
                throw AppError.tournamentLocked
            }
        }
        guard meetsFormatFloor(draft) else { throw AppError.tournamentUpdateFailed }
        guard draft.maxEntries >= tournament.entryCount else { throw AppError.capacityTooLow }
        let updated = store(detail.replacing(tournament: tournament.updating(with: draft, at: now())))
        groups.syncRoom(for: updated.tournament, memberCount: MockTournamentFixtures.playerCount(of: updated))
        logger.info(.tournaments, "Mock tournament \(id) updated (\(updated.tournament.entriesDescription))")
        return resolved(updated)
    }

    /// Whether the cap reaches the format's minimum. The backend refuses less with a bare `VALIDATION_FAILED`, so each
    /// route answers its own fallback.
    private func meetsFormatFloor(_ draft: TournamentDraft) -> Bool {
        draft.maxEntries >= AppConfig.Tournaments.minEntries(for: draft.format)
    }

    func cancel(id: String) async throws -> TournamentDetail {
        let detail = try organized(id)
        guard detail.tournament.status != .completed else { throw AppError.tournamentLocked }
        if detail.tournament.status == .cancelled { return resolved(detail) }
        logger.info(.tournaments, "Mock tournament \(id) cancelled")
        return resolved(store(detail.replacing(tournament: detail.tournament.cancelling(at: now()))))
    }

    /// The detail as a reader may see it: a private tournament is there for its players, its organiser, the members of
    /// the group it is hosted in and the people invited into it; nobody else.
    func readable(_ id: String) throws -> TournamentDetail {
        guard let detail = details[id] else { throw AppError.tournamentNotFound }
        let tournament = detail.tournament
        let isInvited = invitedTournamentIDs.contains(id)
        guard tournament.isPublic || isInRoom(tournament) || isInHostingGroup(tournament) || isInvited else {
            throw AppError.tournamentNotFound
        }
        return detail
    }

    /// The caller holds an invite into the tournament: a private one opens to them from now on.
    func noteInvitee(of id: String) {
        invitedTournamentIDs.insert(id)
    }

    /// The tournament as an accepted invite answers it, whoever may read it: the invitee was let in a moment ago.
    func invited(_ id: String) throws -> Tournament {
        guard let detail = details[id] else { throw AppError.tournamentNotFound }
        return resolved(detail).tournament
    }

    /// The backend's 401 on every write; reads stay anonymous.
    func requireCaller() throws {
        guard identity.currentUserID != nil else { throw AppError.sessionExpired }
    }

    /// The detail for a write only the organiser may make; a guest is refused first.
    func organized(_ id: String) throws -> TournamentDetail {
        try requireCaller()
        let detail = try readable(id)
        guard detail.tournament.organizerUserId == MockTournamentFixtures.callerMarker else { throw AppError.notOrganizer }
        return detail
    }

    @discardableResult
    func store(_ detail: TournamentDetail) -> TournamentDetail {
        details[detail.id] = detail
        return detail
    }

    /// The stored rows with `callerMarker` swapped for the caller of the moment (the entries' members, a match's reporter
    /// and confirmer), and `myEntryId` set from the roster.
    func resolved(_ detail: TournamentDetail) -> TournamentDetail {
        let caller = identity.currentUserID
        let marker = MockTournamentFixtures.callerMarker
        let entries = detail.entries.map { $0.replacingUser(marker, with: caller) }
        let matches = detail.matches.map { $0.replacingUser(marker, with: caller) }
        let tournament = resolved(detail.tournament, myEntryId: detail.entry(containing: marker)?.id)
        return TournamentDetail(tournament: tournament, entries: entries, matches: matches, standings: detail.standings)
    }

    func resolved(_ tournament: Tournament) -> Tournament {
        resolved(tournament, myEntryId: details[tournament.id]?.entry(containing: MockTournamentFixtures.callerMarker)?.id)
    }

    private func resolved(_ tournament: Tournament, myEntryId: String?) -> Tournament {
        let caller = identity.currentUserID
        return tournament.replacingOrganizer(MockTournamentFixtures.callerMarker,
                                             with: caller,
                                             myEntryId: caller == nil ? nil : myEntryId)
    }

    /// Whether the caller is in the tournament's room: its organiser, or in one of its entries.
    func isInRoom(_ tournament: Tournament) -> Bool {
        guard identity.currentUserID != nil, let detail = details[tournament.id] else { return false }
        return tournament.organizerUserId == MockTournamentFixtures.callerMarker
            || detail.entry(containing: MockTournamentFixtures.callerMarker) != nil
    }

    private func isInHostingGroup(_ tournament: Tournament) -> Bool {
        tournament.group.flatMap { groups.find($0.id) }?.isMember ?? false
    }

    /// In progress first, then registration by start, then the finished ones most recently changed first, as the
    /// backend orders Mine.
    private static func mineOrder(_ lhs: Tournament, _ rhs: Tournament) -> Bool {
        let rank: (TournamentStatus) -> Int = { $0 == .inProgress ? 0 : $0 == .registration ? 1 : 2 }
        if rank(lhs.status) != rank(rhs.status) { return rank(lhs.status) < rank(rhs.status) }
        return lhs.status.isOver ? lhs.lastChange > rhs.lastChange : lhs.startsAt < rhs.startsAt
    }
}

private extension Tournament {
    /// When a finished tournament last moved: its completion, else its last edit, else its creation.
    var lastChange: Date { completedAt ?? updatedAt ?? createdAt }
}
