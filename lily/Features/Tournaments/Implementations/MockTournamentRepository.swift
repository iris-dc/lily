import Foundation

/// Fixture tournaments with in-memory entries and matches, for previews, UI tests and `-mock-events` runs. The caller is
/// `MockTournamentFixtures.callerMarker` in every stored row and whoever `identity` names on the way out, so one set of
/// fixtures serves any mock sign-in. The rooms live in the group mock, which this one admits into and leaves.
final class MockTournamentRepository: TournamentRepository {
    /// Stored state is internal, not private, so the `+Entries` and `+Matches` files can reach it.
    var details: [String: TournamentDetail]
    var entrySequence = 0
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

    /// The position is ignored: the fixtures keep their start order, like the backend's upcoming list.
    func tournaments(in scope: TournamentScope, near position: Coordinate?) async throws -> [Tournament] {
        logger.debug(.tournaments, "Mock tournaments served for scope \(scope)")
        let all = details.values.map(\.tournament)
        let moment = now()
        switch scope {
        case .upcoming:
            return all.filter { $0.isListed && $0.startsAt >= moment }.sorted { $0.startsAt < $1.startsAt }.map(resolved)
        case .mine:
            return all.filter(isInRoom).sorted(by: Self.mineOrder).map(resolved)
        case .group(let id):
            return all.filter { $0.group?.id == id && $0.status != .cancelled }.sorted { $0.startsAt < $1.startsAt }.map(resolved)
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
        guard let coordinate = draft.coordinate else { throw AppError.tournamentCreationFailed }
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

    /// Like the backend: the organiser alone; after the start only the name, description and place may differ.
    func update(id: String, _ draft: TournamentDraft) async throws -> TournamentDetail {
        let detail = try organized(id)
        let tournament = detail.tournament
        if tournament.status != .registration {
            guard !tournament.status.isOver, draft.startsAt == tournament.startsAt,
                  draft.registrationClosesAt == tournament.registrationClosesAt,
                  draft.resolvedAllowsDraws == tournament.allowsDraws, draft.maxEntries == tournament.maxEntries else {
                throw AppError.tournamentLocked
            }
        }
        guard draft.maxEntries >= tournament.entryCount else { throw AppError.capacityTooLow }
        let updated = store(detail.replacing(tournament: tournament.updating(with: draft, at: now())))
        groups.syncRoom(for: updated.tournament, memberCount: MockTournamentFixtures.playerCount(of: updated))
        logger.info(.tournaments, "Mock tournament \(id) updated (\(updated.tournament.entriesDescription))")
        return resolved(updated)
    }

    func cancel(id: String) async throws -> TournamentDetail {
        let detail = try organized(id)
        guard detail.tournament.status != .completed else { throw AppError.tournamentLocked }
        if detail.tournament.status == .cancelled { return resolved(detail) }
        logger.info(.tournaments, "Mock tournament \(id) cancelled")
        return resolved(store(detail.replacing(tournament: detail.tournament.cancelling(at: now()))))
    }

    /// The detail as a reader may see it: a private tournament is there for its players, its organiser and the members
    /// of the group it is hosted in; nobody else.
    func readable(_ id: String) throws -> TournamentDetail {
        guard let detail = details[id] else { throw AppError.tournamentNotFound }
        let tournament = detail.tournament
        guard tournament.isPublic || isInRoom(tournament) || isInHostingGroup(tournament) else {
            throw AppError.tournamentNotFound
        }
        return detail
    }

    /// The detail for a write only the organiser may make.
    func organized(_ id: String) throws -> TournamentDetail {
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

    /// In progress first, then registration by start, then the finished ones newest first, as the backend orders Mine.
    private static func mineOrder(_ lhs: Tournament, _ rhs: Tournament) -> Bool {
        let rank: (TournamentStatus) -> Int = { $0 == .inProgress ? 0 : $0 == .registration ? 1 : 2 }
        if rank(lhs.status) != rank(rhs.status) { return rank(lhs.status) < rank(rhs.status) }
        return lhs.status.isOver ? lhs.startsAt > rhs.startsAt : lhs.startsAt < rhs.startsAt
    }
}

extension TournamentEntry {
    /// The entry with `marker` read as `userID` (the caller of the moment) wherever a fixture names them.
    func replacingUser(_ marker: String, with userID: String?) -> TournamentEntry {
        guard let userID, contains(userID: marker) || captainUserId == marker else { return self }
        return TournamentEntry(id: id,
                               tournamentId: tournamentId,
                               name: name,
                               captainUserId: captainUserId == marker ? userID : captainUserId,
                               members: members.map {
                                   $0.userId == marker ? EntryMember(userId: userID, displayName: $0.displayName) : $0
                               },
                               seed: seed,
                               status: status,
                               createdAt: createdAt)
    }
}

private extension Tournament {
    /// The tournament with `marker` read as the caller's id in the organiser's seat, and the caller's entry set.
    func replacingOrganizer(_ marker: String, with userID: String?, myEntryId: String?) -> Tournament {
        Tournament(id: id,
                   name: name,
                   description: description,
                   type: type,
                   format: format,
                   status: status,
                   visibility: visibility,
                   teamSize: teamSize,
                   maxEntries: maxEntries,
                   entryCount: entryCount,
                   allowsDraws: allowsDraws,
                   startsAt: startsAt,
                   registrationClosesAt: registrationClosesAt,
                   location: location,
                   organizerUserId: organizerUserId == marker ? (userID ?? marker) : organizerUserId,
                   organizerName: organizerName,
                   group: group,
                   channelEpoch: channelEpoch,
                   myEntryId: myEntryId,
                   winnerEntryId: winnerEntryId,
                   startedAt: startedAt,
                   completedAt: completedAt,
                   createdAt: createdAt,
                   updatedAt: updatedAt)
    }
}
